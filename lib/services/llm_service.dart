// File: lib/services/llm_service.dart
// Klien HTTP untuk llama-server lokal (API kompatibel OpenAI) di Termux.
// - chat streaming SSE: reasoning_content (berpikir) dipisah dari content (jawaban)
// - embedding: POST /v1/embeddings di port 8081

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:lisku/services/sse_parser.dart';

enum LlmHealth { ok, loading, down }

class LlmException implements Exception {
  final String message;

  LlmException(this.message);

  @override
  String toString() => message;
}

/// Stream chat yang bisa dibatalkan (tombol stop).
class ChatStream {
  final Stream<ChatDelta> stream;
  final void Function() cancel;

  ChatStream(this.stream, this.cancel);
}

class LlmService {
  static const String chatBaseUrl = 'http://127.0.0.1:8080';
  static const String embedBaseUrl = 'http://127.0.0.1:8081';

  final http.Client _client;
  final http.Client Function() _clientFactory;

  LlmService({http.Client? client, http.Client Function()? clientFactory})
      : _client = client ?? http.Client(),
        _clientFactory = clientFactory ?? http.Client.new;

  /// GET /health: 200 = siap, 503 = model masih dimuat, lainnya = mati.
  Future<LlmHealth> health(String baseUrl) async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return LlmHealth.ok;
      if (res.statusCode == 503) return LlmHealth.loading;
      return LlmHealth.down;
    } catch (_) {
      return LlmHealth.down;
    }
  }

  Future<LlmHealth> chatHealth() => health(chatBaseUrl);
  Future<LlmHealth> embedHealth() => health(embedBaseUrl);

  /// Chat streaming. [messages] format OpenAI: [{'role': 'system'|'user'|'assistant', 'content': ...}].
  ChatStream streamChat(
    List<Map<String, String>> messages, {
    double temperature = 0.6,
    double topP = 0.95,
    int topK = 20,
    int? maxTokens,
  }) {
    // Client sendiri per request agar bisa ditutup saat dibatalkan.
    final client = _clientFactory();
    late final StreamController<ChatDelta> controller;
    var cancelled = false;

    Future<void> run() async {
      final request = http.Request('POST', Uri.parse('$chatBaseUrl/v1/chat/completions'))
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode({
          'messages': messages,
          'stream': true,
          'temperature': temperature,
          'top_p': topP,
          'top_k': topK,
          if (maxTokens != null) 'max_tokens': maxTokens,
        });

      try {
        final response = await client.send(request);
        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          throw LlmException(_errorMessage(response.statusCode, body));
        }
        final parser = ChatStreamParser();
        await for (final text in response.stream.transform(utf8.decoder)) {
          if (cancelled) break;
          for (final delta in parser.feed(text)) {
            controller.add(delta);
          }
          if (parser.isDone) break;
        }
        if (!cancelled) {
          for (final delta in parser.close()) {
            controller.add(delta);
          }
        }
      } on LlmStreamException catch (e) {
        if (!cancelled) controller.addError(LlmException(e.message));
      } on LlmException catch (e) {
        if (!cancelled) controller.addError(e);
      } catch (e) {
        if (!cancelled) controller.addError(LlmException('Koneksi ke AI terputus: $e'));
      } finally {
        client.close();
        if (!controller.isClosed) await controller.close();
      }
    }

    void cancel() {
      if (cancelled) return;
      cancelled = true;
      client.close();
      if (!controller.isClosed) controller.close();
    }

    controller = StreamController<ChatDelta>(onListen: run, onCancel: cancel);
    return ChatStream(controller.stream, cancel);
  }

  /// Embedding satu teks. Return vektor.
  Future<List<double>> embed(String text) async {
    final all = await embedBatch([text]);
    return all.first;
  }

  Future<List<List<double>>> embedBatch(List<String> inputs) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$embedBaseUrl/v1/embeddings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': inputs, 'model': 'embeddinggemma'}),
          )
          .timeout(const Duration(minutes: 2));
    } catch (e) {
      throw LlmException('Server embedding tidak bisa dihubungi: $e');
    }
    if (res.statusCode != 200) {
      throw LlmException(_errorMessage(res.statusCode, res.body));
    }
    return parseEmbeddings(res.body, inputs.length);
  }

  static List<List<double>> parseEmbeddings(String body, int expected) {
    final json = jsonDecode(body);
    final data = (json is Map ? json['data'] : null) as List?;
    if (data == null || data.length != expected) {
      throw LlmException('Respons embedding tidak valid');
    }
    final sorted = [...data]..sort((a, b) => ((a['index'] ?? 0) as int).compareTo((b['index'] ?? 0) as int));
    return sorted
        .map((e) => (e['embedding'] as List).map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  static String _errorMessage(int status, String body) {
    try {
      final json = jsonDecode(body);
      final err = json is Map ? json['error'] : null;
      final msg = err is Map ? err['message'] : err;
      if (msg != null) return 'AI error ($status): $msg';
    } catch (_) {
      // bukan JSON
    }
    if (status == 503) return 'Model masih dimuat, coba lagi sebentar.';
    return 'AI error ($status)';
  }
}

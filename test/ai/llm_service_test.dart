import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lisku/services/llm_service.dart';

void main() {
  test('streamChat membaca stream SSE dari server HTTP sungguhan', () async {
    // Server palsu meniru llama-server --reasoning-format deepseek.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      expect(body['stream'], isTrue);
      req.response.headers.contentType = ContentType('text', 'event-stream');
      for (final delta in [
        {'reasoning_content': 'Hmm, '},
        {'reasoning_content': 'pikir dulu.'},
        {'content': 'Jawaban '},
        {'content': 'final.'},
      ]) {
        req.response.write('data: ${jsonEncode({
              'choices': [
                {'delta': delta}
              ]
            })}\n\n');
        await req.response.flush();
      }
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });

    final llm = _PortLlm(server.port);
    final deltas = await llm.streamTo([
      {'role': 'user', 'content': 'halo'}
    ]);
    expect(deltas.map((d) => d.reasoning).join(), 'Hmm, pikir dulu.');
    expect(deltas.map((d) => d.content).join(), 'Jawaban final.');
    await server.close(force: true);
  });

  test('parseEmbeddings mengurutkan berdasarkan index', () {
    final body = jsonEncode({
      'data': [
        {'index': 1, 'embedding': [0.5, 0.5]},
        {'index': 0, 'embedding': [1, 0]},
      ]
    });
    expect(LlmService.parseEmbeddings(body, 2), [
      [1.0, 0.0],
      [0.5, 0.5]
    ]);
  });

  test('health membedakan siap / memuat / mati', () async {
    Future<LlmHealth> check(int status) =>
        LlmService(client: MockClient((_) async => http.Response('', status))).chatHealth();
    expect(await check(200), LlmHealth.ok);
    expect(await check(503), LlmHealth.loading);
    expect(await LlmService(client: MockClient((_) async => throw const SocketException('refused')))
        .chatHealth(), LlmHealth.down);
  });
}

/// Mengarahkan request ke port server palsu.
class _PortLlm {
  final int port;

  _PortLlm(this.port);

  Future<List> streamTo(List<Map<String, String>> messages) async {
    final llm = LlmService(clientFactory: () => _RewriteClient(port));
    return llm.streamChat(messages).stream.toList();
  }
}

class _RewriteClient extends http.BaseClient {
  final int port;
  final http.Client _inner = http.Client();

  _RewriteClient(this.port);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final req = request as http.Request;
    final copy = http.Request(req.method, req.url.replace(port: port))
      ..headers.addAll(req.headers)
      ..body = req.body;
    return _inner.send(copy);
  }

  @override
  void close() => _inner.close();
}

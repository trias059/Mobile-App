// File: lib/services/llm_service.dart
// Klien HTTP untuk llama-server lokal (API kompatibel OpenAI) di Termux.

import 'dart:async';

import 'package:http/http.dart' as http;

enum LlmHealth { ok, loading, down }

class LlmService {
  static const String chatBaseUrl = 'http://127.0.0.1:8080';
  static const String embedBaseUrl = 'http://127.0.0.1:8081';

  final http.Client _client;

  LlmService({http.Client? client}) : _client = client ?? http.Client();

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
}

// File: lib/services/sse_parser.dart
// Parser Server-Sent Events untuk streaming chat llama-server (format OpenAI).
// Memisahkan "reasoning_content" (proses berpikir) dan "content" (jawaban).

import 'dart:convert';

/// Satu potongan delta dari stream chat.
class ChatDelta {
  final String reasoning;
  final String content;
  final String? finishReason;

  const ChatDelta({this.reasoning = '', this.content = '', this.finishReason});

  bool get isEmpty => reasoning.isEmpty && content.isEmpty && finishReason == null;

  @override
  String toString() => 'ChatDelta(reasoning: "$reasoning", content: "$content", finish: $finishReason)';
}

/// Memecah teks SSE (yang bisa datang terpotong di tengah baris) menjadi
/// payload `data:` per event. Payload `[DONE]` dikembalikan apa adanya.
class SseLineDecoder {
  String _buffer = '';
  final List<String> _dataLines = [];

  List<String> feed(String chunk) {
    _buffer += chunk;
    final events = <String>[];
    while (true) {
      final newline = _buffer.indexOf('\n');
      if (newline < 0) break;
      var line = _buffer.substring(0, newline);
      _buffer = _buffer.substring(newline + 1);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);

      if (line.isEmpty) {
        // Baris kosong = akhir event.
        if (_dataLines.isNotEmpty) {
          events.add(_dataLines.join('\n'));
          _dataLines.clear();
        }
      } else if (line.startsWith(':')) {
        // komentar / keep-alive
      } else if (line.startsWith('data:')) {
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        _dataLines.add(data);
      }
      // field lain (event:, id:, retry:) tidak dipakai
    }
    return events;
  }

  /// Panggil saat stream selesai untuk mengeluarkan event terakhir tanpa baris kosong.
  List<String> close() {
    final rest = feed('\n\n');
    _buffer = '';
    return rest;
  }
}

/// Fallback bila server tidak memisahkan reasoning: memindahkan teks di dalam
/// `<think>...</think>` dari content ke reasoning. Aman untuk tag yang terpotong
/// di antara dua chunk.
class ThinkTagSplitter {
  static const String _open = '<think>';
  static const String _close = '</think>';

  bool _inThink = false;
  String _pending = '';

  ChatDelta feed(String text) {
    _pending += text;
    final reasoning = StringBuffer();
    final content = StringBuffer();

    while (_pending.isNotEmpty) {
      final tag = _inThink ? _close : _open;
      final idx = _pending.indexOf(tag);
      if (idx >= 0) {
        (_inThink ? reasoning : content).write(_pending.substring(0, idx));
        _pending = _pending.substring(idx + tag.length);
        _inThink = !_inThink;
        continue;
      }
      // Tahan akhiran yang mungkin awal dari tag.
      final hold = _partialTagSuffix(_pending, tag);
      (_inThink ? reasoning : content).write(_pending.substring(0, _pending.length - hold));
      _pending = _pending.substring(_pending.length - hold);
      break;
    }
    return ChatDelta(reasoning: reasoning.toString(), content: content.toString());
  }

  ChatDelta flush() {
    final rest = _pending;
    _pending = '';
    return _inThink ? ChatDelta(reasoning: rest) : ChatDelta(content: rest);
  }

  static int _partialTagSuffix(String text, String tag) {
    for (var len = tag.length - 1; len > 0; len--) {
      if (text.length >= len && text.endsWith(tag.substring(0, len))) return len;
    }
    return 0;
  }
}

/// Mengubah aliran teks SSE menjadi [ChatDelta] (reasoning vs content).
class ChatStreamParser {
  final SseLineDecoder _decoder = SseLineDecoder();
  final ThinkTagSplitter _splitter = ThinkTagSplitter();
  bool _done = false;

  bool get isDone => _done;

  List<ChatDelta> feed(String chunk) => _parseEvents(_decoder.feed(chunk));

  List<ChatDelta> close() {
    final deltas = _parseEvents(_decoder.close());
    final rest = _splitter.flush();
    if (!rest.isEmpty) deltas.add(rest);
    return deltas;
  }

  List<ChatDelta> _parseEvents(List<String> events) {
    final deltas = <ChatDelta>[];
    for (final data in events) {
      if (data.trim() == '[DONE]') {
        _done = true;
        continue;
      }
      final delta = parseChunk(data, _splitter);
      if (delta != null && !delta.isEmpty) deltas.add(delta);
    }
    return deltas;
  }

  /// Parse satu payload JSON `chat.completion.chunk`.
  static ChatDelta? parseChunk(String data, [ThinkTagSplitter? splitter]) {
    final dynamic json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    if (json['error'] != null) {
      final err = json['error'];
      throw LlmStreamException(err is Map ? '${err['message'] ?? err}' : '$err');
    }
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final choice = choices.first;
    if (choice is! Map) return null;
    final delta = (choice['delta'] ?? choice['message']) as Map? ?? const {};

    final reasoning = (delta['reasoning_content'] ?? delta['reasoning'] ?? '') as String? ?? '';
    final rawContent = delta['content'] as String? ?? '';
    final finish = choice['finish_reason'] as String?;

    if (splitter == null) {
      return ChatDelta(reasoning: reasoning, content: rawContent, finishReason: finish);
    }
    final split = splitter.feed(rawContent);
    return ChatDelta(
      reasoning: reasoning + split.reasoning,
      content: split.content,
      finishReason: finish,
    );
  }
}

class LlmStreamException implements Exception {
  final String message;

  LlmStreamException(this.message);

  @override
  String toString() => message;
}

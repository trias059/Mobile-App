import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/services/sse_parser.dart';

String chunk({String? reasoning, String? content, String? finish}) {
  return 'data: ${jsonEncode({
        'object': 'chat.completion.chunk',
        'choices': [
          {
            'index': 0,
            'delta': {
              if (reasoning != null) 'reasoning_content': reasoning,
              if (content != null) 'content': content,
            },
            'finish_reason': finish,
          }
        ],
      })}\n\n';
}

void main() {
  group('SseLineDecoder', () {
    test('menggabungkan baris yang terpotong antar chunk', () {
      final d = SseLineDecoder();
      expect(d.feed('data: {"a"'), isEmpty);
      expect(d.feed(':1}\n'), isEmpty);
      expect(d.feed('\n'), ['{"a":1}']);
    });

    test('mendukung CRLF, komentar, dan [DONE]', () {
      final d = SseLineDecoder();
      expect(d.feed(': keep-alive\r\n\r\ndata: x\r\n\r\ndata: [DONE]\r\n\r\n'), ['x', '[DONE]']);
    });

    test('close mengeluarkan event terakhir tanpa baris kosong', () {
      final d = SseLineDecoder();
      expect(d.feed('data: akhir'), isEmpty);
      expect(d.close(), ['akhir']);
    });
  });

  group('ChatStreamParser (reasoning vs content)', () {
    test('memisahkan reasoning_content dan content', () {
      final p = ChatStreamParser();
      final deltas = p.feed(chunk(reasoning: 'Pengguna bertanya ') +
          chunk(reasoning: 'tentang tidur.') +
          chunk(content: 'Tidurlah ') +
          chunk(content: '7-9 jam.', finish: 'stop') +
          'data: [DONE]\n\n');
      final reasoning = deltas.map((d) => d.reasoning).join();
      final content = deltas.map((d) => d.content).join();
      expect(reasoning, 'Pengguna bertanya tentang tidur.');
      expect(content, 'Tidurlah 7-9 jam.');
      expect(deltas.last.finishReason, 'stop');
      expect(p.isDone, isTrue);
    });

    test('tahan terhadap chunk jaringan yang memotong JSON di tengah', () {
      final full = chunk(reasoning: 'mikir') + chunk(content: 'jawab') + 'data: [DONE]\n\n';
      final p = ChatStreamParser();
      final deltas = <ChatDelta>[];
      for (var i = 0; i < full.length; i += 7) {
        deltas.addAll(p.feed(full.substring(i, (i + 7).clamp(0, full.length))));
      }
      expect(deltas.map((d) => d.reasoning).join(), 'mikir');
      expect(deltas.map((d) => d.content).join(), 'jawab');
    });

    test('fallback <think> di dalam content dipindah ke reasoning', () {
      final p = ChatStreamParser();
      final deltas = [
        ...p.feed(chunk(content: '<thi')),
        ...p.feed(chunk(content: 'nk>rahasia ')),
        ...p.feed(chunk(content: 'pikiran</th')),
        ...p.feed(chunk(content: 'ink>\n\nHalo!')),
        ...p.close(),
      ];
      expect(deltas.map((d) => d.reasoning).join(), 'rahasia pikiran');
      expect(deltas.map((d) => d.content).join(), '\n\nHalo!');
    });

    test('content biasa yang mengandung "<" tidak hilang', () {
      final p = ChatStreamParser();
      final deltas = [...p.feed(chunk(content: 'a < b dan <')), ...p.close()];
      expect(deltas.map((d) => d.content).join(), 'a < b dan <');
    });

    test('error dari server dilempar', () {
      expect(() => ChatStreamParser().feed('data: {"error":{"message":"context penuh"}}\n\n'),
          throwsA(isA<LlmStreamException>()));
    });
  });
}

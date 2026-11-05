import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lisku/model/knowledge_models.dart';
import 'package:lisku/services/knowledge_service.dart';
import 'package:lisku/services/llm_service.dart';

/// Embedding palsu: dimensi = kata kunci.
List<double> fakeEmbed(String text) {
  final t = text.toLowerCase();
  return [
    for (final k in ['tidur', 'uang', 'olahraga']) t.contains(k) ? 1.0 : 0.05,
  ];
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('lisku_kb');
    Hive.init(dir.path);
    Hive.registerAdapter(KnowledgeChunkAdapter());
    Hive.registerAdapter(KnowledgeSourceAdapter());
    await KnowledgeService.open();
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('catatan di-embed, dicari dengan cosine, dan bisa dihapus', () async {
    final requests = <String>[];
    final client = MockClient((req) async {
      final input = (jsonDecode(req.body)['input'] as List).cast<String>();
      requests.addAll(input);
      return http.Response(
        jsonEncode({
          'data': [
            for (var i = 0; i < input.length; i++) {'index': i, 'embedding': fakeEmbed(input[i])}
          ]
        }),
        200,
      );
    });
    final kb = KnowledgeService(LlmService(client: client));

    final sleep = await kb.addNote(title: 'Tidur', text: 'Tidur 8 jam membuat fokus.');
    await kb.addNote(title: '', text: 'Sisihkan uang 20 persen tiap gajian.');
    await kb.addNote(title: 'Olahraga', text: 'Olahraga pagi 15 menit.');

    expect(requests.first, startsWith('title: Tidur | text: '));
    expect(KnowledgeService.notes(), hasLength(3));
    expect(KnowledgeService.notes().any((n) => n.title.startsWith('Sisihkan uang')), isTrue);

    final ctx = await kb.retrieve('berapa lama sebaiknya tidur?');
    expect(requests.last, startsWith('task: search result | query: '));
    expect(ctx.chunks, hasLength(3));
    expect(ctx.chunks.first.item.title, 'Tidur');
    expect(ctx.sourceLabels.first, '[1] Tidur (catatan pribadi)');
    expect(ctx.promptText, contains('[1] Sumber: Tidur (catatan pribadi)'));

    await KnowledgeService.deleteSource(sleep);
    expect(KnowledgeService.notes(), hasLength(2));
    expect(KnowledgeService.chunks.values.where((c) => c.sourceId == sleep.id), isEmpty);
  });
}

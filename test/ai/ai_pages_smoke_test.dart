import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:lisku/model/ai_chat_message.dart';
import 'package:lisku/model/knowledge_models.dart';
import 'package:lisku/pages/ai_assistant_page.dart';
import 'package:lisku/pages/ai_chat_page.dart';
import 'package:lisku/pages/ai_insight_page.dart';
import 'package:lisku/pages/ai_knowledge_page.dart';
import 'package:lisku/pages/ai_settings_page.dart';
import 'package:lisku/services/ai_chat_repository.dart';
import 'package:lisku/services/ai_server_controller.dart';
import 'package:lisku/services/knowledge_service.dart';

void main() {
  late Directory dir;
  late AiServerController ai;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('lisku_ui');
    Hive.init(dir.path);
    Hive.registerAdapter(AiChatMessageAdapter());
    Hive.registerAdapter(KnowledgeChunkAdapter());
    Hive.registerAdapter(KnowledgeSourceAdapter());
    await AiChatRepository.open();
    await KnowledgeService.open();
    await AiChatRepository.add(AiChatMessage(
      id: '1', role: 'user', content: 'Apa itu habit?', persona: 'teacher', createdAt: DateTime(2026)));
    await AiChatRepository.add(AiChatMessage(
      id: '2',
      role: 'assistant',
      content: '**Habit** adalah kebiasaan kecil [1].',
      reasoning: 'Pengguna bertanya definisi.',
      persona: 'teacher',
      createdAt: DateTime(2026, 1, 2),
      sources: ['[1] Atomic Habits, hal. 3–4'],
      question: 'Apa itu habit?',
    ));
    await KnowledgeService.sources.put('n1', KnowledgeSource(
        id: 'n1', type: 'note', title: 'Tidur', createdAt: DateTime(2026), text: 'Tidur 8 jam'));
    await KnowledgeService.sources.put('b1', KnowledgeSource(
        id: 'b1', type: 'book', title: 'Atomic Habits', createdAt: DateTime(2026), pageCount: 300, chunkCount: 120));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    ai.dispose();
  }

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      ai = AiServerController();
      await ai.init();
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: ai,
      child: MaterialApp(home: page),
    ));
    // Termux tidak ada di test -> status "Termux belum terinstall".
    await settle(tester);
  }

  testWidgets('hub AI tampil dan menunjukkan Termux belum terinstall', (tester) async {
    await pump(tester, const AiAssistantPage());
    expect(find.text('Asisten AI'), findsOneWidget);
    expect(find.textContaining('Termux belum terinstall'), findsOneWidget);
    expect(find.text('Guru e-book'), findsOneWidget);
    await tester.scrollUntilVisible(find.byIcon(Icons.download), 300);
    expect(find.text('Setup AI'), findsWidgets);
    await done(tester);
  });

  testWidgets('chat: sumber tampil, proses berpikir tersembunyi lalu bisa dibuka', (tester) async {
    await pump(tester, const AiChatPage(initialPersona: 'teacher'));
    expect(find.textContaining('Atomic Habits, hal. 3–4'), findsOneWidget);
    expect(find.text('Pengguna bertanya definisi.'), findsNothing);
    await tester.tap(find.text('Lihat proses berpikir'));
    await tester.pump();
    expect(find.text('Pengguna bertanya definisi.'), findsOneWidget);
    expect(find.text('Simpan sebagai insight'), findsOneWidget);
    await tester.tap(find.text('Koreksi'));
    await tester.pump();
    expect(find.text('Tulis koreksi: jawaban yang benar...'), findsOneWidget);

    // Kirim pesan saat Termux tidak ada -> pesan error yang jelas.
    await tester.enterText(find.byType(TextField).last, 'Halo');
    await tester.tap(find.byIcon(Icons.send));
    await settle(tester);
    expect(find.textContaining('AI belum siap'), findsOneWidget);
    await done(tester);
  });

  testWidgets('halaman pengaturan, insight, dan kelola pengetahuan', (tester) async {
    await pump(tester, const AiSettingsPage());
    expect(find.text('Default (Qwen3 1.7B)'), findsWidgets);
    expect(find.text('Uncensored (Gemma 4 E2B)'), findsOneWidget);

    await done(tester);
    await pump(tester, const AiInsightPage());
    expect(find.text('Tidur'), findsOneWidget);
    expect(find.textContaining('catatan pribadi'), findsOneWidget);

    await done(tester);
    await pump(tester, const AiKnowledgePage());
    expect(find.text('Atomic Habits'), findsOneWidget);
    expect(find.textContaining('300 halaman'), findsOneWidget);
    expect(find.text('Impor PDF'), findsOneWidget);
    await done(tester);
  });
}

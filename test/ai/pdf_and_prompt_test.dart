import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/model/ai_chat_message.dart';
import 'package:lisku/services/ai_chat_repository.dart';
import 'package:lisku/services/ai_personas.dart';
import 'package:lisku/services/pdf_text_extractor.dart';
import 'package:lisku/services/text_chunker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('ekstrak teks PDF per halaman lalu potong dengan nomor halaman', () async {
    final doc = PdfDocument();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    for (final text in ['Halaman pertama tentang kebiasaan', 'Halaman kedua tentang tidur']) {
      doc.pages.add().graphics.drawString(text, font);
    }
    final bytes = Uint8List.fromList(await doc.save());
    doc.dispose();

    final pages = await PdfTextExtractorService.extractPages(bytes);
    expect(pages, hasLength(2));
    expect(pages[0], contains('kebiasaan'));
    expect(pages[1], contains('tidur'));

    final chunks = TextChunker.chunkPages(pages);
    expect(chunks.single.startPage, 1);
    expect(chunks.single.endPage, 2);
  });

  AiChatMessage msg(String role, String content, {bool error = false}) => AiChatMessage(
        id: content,
        role: role,
        content: content,
        persona: 'advisor',
        createdAt: DateTime(2026),
        isError: error,
      );

  test('prompt: system + riwayat valid + pertanyaan, pesan error dilewati', () {
    final prompt = AiChatRepository.buildPrompt(
      persona: AiPersona.advisor,
      history: [
        msg('assistant', 'yatim'), // tanpa pesan user sebelumnya -> dibuang
        msg('user', 'q1'),
        msg('assistant', 'a1'),
        msg('user', 'q2'),
        msg('assistant', 'gagal', error: true),
      ],
      userText: 'q3',
    );
    expect(prompt.first['role'], 'system');
    expect(prompt.first['content'], contains('bahasa Indonesia'));
    expect(prompt.skip(1).map((m) => m['content']), ['q1', 'a1', 'q2', 'q3']);
  });

  test('prompt RAG menyisipkan konteks ke pesan user', () {
    final prompt = AiChatRepository.buildPrompt(
      persona: AiPersona.teacher,
      history: const [],
      userText: 'Apa itu habit?',
      context: '[1] Sumber: Buku, hal. 3\nHabit adalah ...',
    );
    expect(prompt, hasLength(2));
    expect(prompt.last['content'], contains('KONTEKS:'));
    expect(prompt.last['content'], contains('Apa itu habit?'));
  });
}

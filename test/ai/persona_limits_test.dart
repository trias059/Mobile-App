import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/model/ai_chat_message.dart';
import 'package:lisku/services/ai_personas.dart';

void main() {
  group('maxTokens per persona', () {
    test('peran dengan thinking = 1500, tanpa thinking = 600', () {
      for (final p in AiPersona.all) {
        expect(p.maxTokens, p.thinking ? 1500 : 600, reason: p.name);
      }
    });

    test('nilai per peran', () {
      expect(AiPersona.advisor.thinking, isTrue);
      expect(AiPersona.advisor.maxTokens, 1500);
      expect(AiPersona.teacher.thinking, isTrue);
      expect(AiPersona.teacher.maxTokens, 1500);
      expect(AiPersona.etiquette.thinking, isFalse);
      expect(AiPersona.etiquette.maxTokens, 600);
    });
  });

  group('AiChatMessage stopReason "length"', () {
    AiChatMessage answer(String content, String stopReason) => AiChatMessage(
          id: 'x',
          role: 'assistant',
          content: content,
          reasoning: 'proses berpikir',
          persona: 'advisor',
          createdAt: DateTime(2026),
          stopReason: stopReason,
        );

    test('ada jawaban = terpotong', () {
      final m = answer('Sebagian jawaban', 'length');
      expect(m.isTruncated, isTrue);
      expect(m.isThinkingOverflow, isFalse);
    });

    test('belum ada jawaban = berpikir terlalu lama', () {
      final m = answer('', 'length');
      expect(m.isThinkingOverflow, isTrue);
      expect(m.isTruncated, isFalse);
      expect(m.reasoning, isNotEmpty); // tetap bisa dilihat
    });

    test('selesai normal', () {
      final m = answer('Jawaban lengkap', '');
      expect(m.isTruncated, isFalse);
      expect(m.isThinkingOverflow, isFalse);
    });

    test('pesan untuk user', () {
      expect(AiChatMessage.truncatedNote, 'Jawaban terpotong. Coba tanya lebih spesifik.');
      expect(AiChatMessage.thinkingTooLongNote,
          'Model berpikir terlalu lama. Coba ulangi atau sederhanakan pertanyaan.');
    });
  });
}

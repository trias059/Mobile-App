// File: lib/services/ai_chat_repository.dart
// Riwayat chat Asisten AI (Hive) + penyusunan prompt untuk llama-server.

import 'package:hive_flutter/hive_flutter.dart';

import 'package:lisku/model/ai_chat_message.dart';
import 'package:lisku/services/ai_personas.dart';

class AiChatRepository {
  static const String boxName = 'ai_chat_messages';

  /// Riwayat yang dikirim ulang ke model (konteks 4096 token, jadi dibatasi).
  static const int historyMessages = 6;
  static const int historyCharBudget = 4000;

  static Future<Box<AiChatMessage>> open() => Hive.openBox<AiChatMessage>(boxName);

  static Box<AiChatMessage> get box => Hive.box<AiChatMessage>(boxName);

  static List<AiChatMessage> messagesFor(String persona) {
    final list = box.values.where((m) => m.persona == persona).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static Future<AiChatMessage> add(AiChatMessage message) async {
    await box.put(message.id, message);
    return message;
  }

  static Future<void> clear(String persona) async {
    final keys = box.values.where((m) => m.persona == persona).map((m) => m.key).toList();
    await box.deleteAll(keys);
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Susun pesan format OpenAI: system + riwayat terakhir + pertanyaan baru.
  /// [context] (opsional) disisipkan ke pesan user terakhir untuk RAG.
  static List<Map<String, String>> buildPrompt({
    required AiPersona persona,
    required List<AiChatMessage> history,
    required String userText,
    String? context,
    int maxHistory = historyMessages,
    int charBudget = historyCharBudget,
  }) {
    final usable = history.where((m) => !m.isError && m.content.trim().isNotEmpty).toList();
    final picked = <AiChatMessage>[];
    var chars = 0;
    for (final m in usable.reversed) {
      if (picked.length >= maxHistory) break;
      if (chars + m.content.length > charBudget) break;
      chars += m.content.length;
      picked.insert(0, m);
    }
    // Riwayat harus diawali pesan user agar template chat valid.
    while (picked.isNotEmpty && !picked.first.isUser) {
      picked.removeAt(0);
    }

    final user = context == null
        ? userText
        : 'KONTEKS:\n$context\n\nPERTANYAAN: $userText\n\n'
            'Jawab hanya dari KONTEKS di atas dan sebutkan sumbernya dengan nomor [n].';

    return [
      {'role': 'system', 'content': persona.systemPrompt},
      for (final m in picked) {'role': m.isUser ? 'user' : 'assistant', 'content': m.content},
      {'role': 'user', 'content': user},
    ];
  }
}

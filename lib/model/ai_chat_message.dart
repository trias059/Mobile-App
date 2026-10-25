import 'package:hive/hive.dart';

part 'ai_chat_message.g.dart';

/// Satu pesan di chat Asisten AI (disimpan di box 'ai_chat_messages').
@HiveType(typeId: 50)
class AiChatMessage extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String role; // 'user' | 'assistant'

  @HiveField(2)
  String content;

  @HiveField(3)
  String reasoning; // proses berpikir model (reasoning_content), tersembunyi default

  @HiveField(4)
  String persona; // 'advisor' | 'etiquette' | 'teacher'

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  List<String> sources; // sumber RAG, mis. "Atomic Habits, hal. 12"

  @HiveField(7)
  bool isError;

  @HiveField(8)
  String? question; // pertanyaan user yang dijawab (untuk insight)

  @HiveField(9)
  String? model; // 'default' | 'uncensored'

  AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.reasoning = '',
    required this.persona,
    required this.createdAt,
    this.sources = const [],
    this.isError = false,
    this.question,
    this.model,
  });

  bool get isUser => role == 'user';
}

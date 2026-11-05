import 'package:hive/hive.dart';

part 'knowledge_models.g.dart';

/// Sumber pengetahuan: buku PDF atau catatan pribadi (box 'ai_knowledge_sources').
@HiveType(typeId: 52)
class KnowledgeSource extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type; // 'book' | 'note'

  @HiveField(2)
  String title;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  int pageCount;

  @HiveField(5)
  int chunkCount;

  @HiveField(6)
  String text; // isi catatan (kosong untuk buku)

  KnowledgeSource({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.pageCount = 0,
    this.chunkCount = 0,
    this.text = '',
  });

  bool get isBook => type == 'book';
  bool get isNote => type == 'note';
}

/// Potongan teks + vektor embedding (box 'ai_knowledge_chunks').
@HiveType(typeId: 51)
class KnowledgeChunk extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sourceId;

  @HiveField(2)
  String sourceType; // 'book' | 'note'

  @HiveField(3)
  String title; // judul buku / catatan

  @HiveField(4)
  int startPage; // 0 untuk catatan

  @HiveField(5)
  int endPage;

  @HiveField(6)
  String text;

  @HiveField(7)
  List<double> embedding;

  KnowledgeChunk({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.title,
    required this.startPage,
    required this.endPage,
    required this.text,
    required this.embedding,
  });

  /// Label sumber yang ditampilkan di bawah jawaban.
  String get sourceLabel {
    if (sourceType == 'note') return '$title (catatan pribadi)';
    if (startPage == endPage) return '$title, hal. $startPage';
    return '$title, hal. $startPage–$endPage';
  }
}

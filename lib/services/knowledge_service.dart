// File: lib/services/knowledge_service.dart
// Indeks pengetahuan untuk RAG: buku PDF & catatan pribadi (insight),
// disimpan di Hive beserta vektor embedding dari server port 8081.

import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:lisku/model/knowledge_models.dart';
import 'package:lisku/services/llm_service.dart';
import 'package:lisku/services/pdf_text_extractor.dart';
import 'package:lisku/services/text_chunker.dart';
import 'package:lisku/services/vector_math.dart';

class ImportProgress {
  final String stage;
  final int done;
  final int total;

  const ImportProgress(this.stage, {this.done = 0, this.total = 0});

  double? get fraction => total == 0 ? null : done / total;
}

class KnowledgeException implements Exception {
  final String message;

  KnowledgeException(this.message);

  @override
  String toString() => message;
}

class RetrievedContext {
  final List<ScoredItem<KnowledgeChunk>> chunks;

  const RetrievedContext(this.chunks);

  bool get isEmpty => chunks.isEmpty;

  /// Konteks bernomor untuk prompt.
  String get promptText {
    final buffer = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i].item;
      buffer
        ..writeln('[${i + 1}] Sumber: ${c.sourceLabel}')
        ..writeln(c.text)
        ..writeln();
    }
    return buffer.toString().trim();
  }

  /// Label sumber yang ditampilkan di bawah jawaban.
  List<String> get sourceLabels =>
      [for (var i = 0; i < chunks.length; i++) '[${i + 1}] ${chunks[i].item.sourceLabel}'];
}

class KnowledgeService {
  static const String sourcesBoxName = 'ai_knowledge_sources';
  static const String chunksBoxName = 'ai_knowledge_chunks';
  static const int topK = 3;

  final LlmService llm;

  KnowledgeService(this.llm);

  static Future<void> open() async {
    await Hive.openBox<KnowledgeSource>(sourcesBoxName);
    await Hive.openBox<KnowledgeChunk>(chunksBoxName);
  }

  static Box<KnowledgeSource> get sources => Hive.box<KnowledgeSource>(sourcesBoxName);
  static Box<KnowledgeChunk> get chunks => Hive.box<KnowledgeChunk>(chunksBoxName);

  static List<KnowledgeSource> books() =>
      sources.values.where((s) => s.isBook).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static List<KnowledgeSource> notes() =>
      sources.values.where((s) => s.isNote).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static bool get isEmpty => chunks.isEmpty;

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // Prefix yang direkomendasikan untuk EmbeddingGemma.
  static String documentInput(String title, String text) => 'title: $title | text: $text';
  static String queryInput(String query) => 'task: search result | query: $query';

  // ================= IMPOR PDF =================

  Future<KnowledgeSource> importPdf(
    String path, {
    required String title,
    required void Function(ImportProgress) onProgress,
    bool Function()? isCancelled,
  }) async {
    onProgress(const ImportProgress('Membaca PDF...'));
    final List<String> pages;
    try {
      pages = await PdfTextExtractorService.extractPages(await File(path).readAsBytes());
    } catch (e) {
      throw KnowledgeException('PDF tidak bisa dibaca: $e');
    }

    final pieces = TextChunker.chunkPages(pages);
    if (pieces.isEmpty) {
      throw KnowledgeException('PDF tidak berisi teks yang bisa dibaca (mungkin hasil scan/gambar).');
    }

    final source = KnowledgeSource(
      id: _newId(),
      type: 'book',
      title: title,
      createdAt: DateTime.now(),
      pageCount: pages.length,
    );

    final created = <KnowledgeChunk>[];
    try {
      for (var i = 0; i < pieces.length; i++) {
        if (isCancelled?.call() == true) throw KnowledgeException('Impor dibatalkan.');
        onProgress(ImportProgress('Membuat embedding...', done: i, total: pieces.length));
        final piece = pieces[i];
        final vector = await llm.embed(documentInput(title, piece.text));
        final chunk = KnowledgeChunk(
          id: '${source.id}_$i',
          sourceId: source.id,
          sourceType: 'book',
          title: title,
          startPage: piece.startPage,
          endPage: piece.endPage,
          text: piece.text,
          embedding: vector,
        );
        await chunks.put(chunk.id, chunk);
        created.add(chunk);
      }
    } catch (e) {
      // Rollback agar tidak ada buku setengah jadi.
      await chunks.deleteAll(created.map((c) => c.id));
      if (e is KnowledgeException) rethrow;
      throw KnowledgeException('Gagal membuat embedding: $e');
    }

    source.chunkCount = created.length;
    await sources.put(source.id, source);
    onProgress(ImportProgress('Selesai', done: pieces.length, total: pieces.length));
    return source;
  }

  // ================= CATATAN PRIBADI / INSIGHT =================

  Future<KnowledgeSource> addNote({required String title, required String text}) async {
    final cleanTitle = title.trim().isEmpty ? _titleFrom(text) : title.trim();
    final source = KnowledgeSource(
      id: _newId(),
      type: 'note',
      title: cleanTitle,
      createdAt: DateTime.now(),
      text: text.trim(),
    );
    final pieces = TextChunker.chunkText(text);
    if (pieces.isEmpty) throw KnowledgeException('Catatan masih kosong.');

    final created = <KnowledgeChunk>[];
    try {
      for (var i = 0; i < pieces.length; i++) {
        final vector = await llm.embed(documentInput(cleanTitle, pieces[i]));
        final chunk = KnowledgeChunk(
          id: '${source.id}_$i',
          sourceId: source.id,
          sourceType: 'note',
          title: cleanTitle,
          startPage: 0,
          endPage: 0,
          text: pieces[i],
          embedding: vector,
        );
        await chunks.put(chunk.id, chunk);
        created.add(chunk);
      }
    } catch (e) {
      await chunks.deleteAll(created.map((c) => c.id));
      throw KnowledgeException('Gagal menyimpan insight: $e');
    }
    source.chunkCount = created.length;
    await sources.put(source.id, source);
    return source;
  }

  static String _titleFrom(String text) {
    final firstLine = text.trim().split('\n').first.trim();
    return firstLine.length <= 50 ? firstLine : '${firstLine.substring(0, 50)}…';
  }

  // ================= HAPUS =================

  static Future<void> deleteSource(KnowledgeSource source) async {
    final keys = chunks.values.where((c) => c.sourceId == source.id).map((c) => c.key).toList();
    await chunks.deleteAll(keys);
    await source.delete();
  }

  // ================= PENCARIAN =================

  Future<RetrievedContext> retrieve(String question, {int k = topK}) async {
    if (isEmpty) return const RetrievedContext([]);
    final query = await llm.embed(queryInput(question));
    return RetrievedContext(
      VectorMath.topK<KnowledgeChunk>(query, chunks.values, (c) => c.embedding, k: k),
    );
  }
}

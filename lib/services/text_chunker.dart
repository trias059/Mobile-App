// File: lib/services/text_chunker.dart
// Memotong teks buku per halaman menjadi potongan ±500 kata (overlap ±50 kata),
// tetap mengingat nomor halaman awal & akhir tiap potongan.

class TextChunk {
  final String text;
  final int startPage; // 1-based
  final int endPage;
  final int wordCount;

  const TextChunk({
    required this.text,
    required this.startPage,
    required this.endPage,
    required this.wordCount,
  });

  @override
  String toString() => 'TextChunk(p$startPage-$endPage, $wordCount kata)';
}

class TextChunker {
  static const int defaultChunkWords = 500;
  static const int defaultOverlapWords = 50;

  /// [pages] = teks tiap halaman (index 0 = halaman 1). Halaman kosong dilewati,
  /// tapi nomor halaman tetap sesuai PDF.
  static List<TextChunk> chunkPages(
    List<String> pages, {
    int chunkWords = defaultChunkWords,
    int overlapWords = defaultOverlapWords,
  }) {
    assert(chunkWords > 0);
    assert(overlapWords >= 0 && overlapWords < chunkWords);

    final words = <String>[];
    final wordPages = <int>[];
    for (var i = 0; i < pages.length; i++) {
      for (final w in splitWords(pages[i])) {
        words.add(w);
        wordPages.add(i + 1);
      }
    }
    if (words.isEmpty) return const [];

    final chunks = <TextChunk>[];
    final step = chunkWords - overlapWords;
    var start = 0;
    while (start < words.length) {
      final end = (start + chunkWords).clamp(0, words.length);
      // Potongan terakhir yang terlalu kecil digabung ke potongan sebelumnya.
      final remaining = words.length - end;
      final finalEnd = remaining > 0 && remaining < overlapWords ? words.length : end;

      chunks.add(TextChunk(
        text: words.sublist(start, finalEnd).join(' '),
        startPage: wordPages[start],
        endPage: wordPages[finalEnd - 1],
        wordCount: finalEnd - start,
      ));
      if (finalEnd >= words.length) break;
      start += step;
    }
    return chunks;
  }

  /// Potong teks bebas (mis. catatan pribadi) tanpa nomor halaman.
  static List<String> chunkText(
    String text, {
    int chunkWords = defaultChunkWords,
    int overlapWords = defaultOverlapWords,
  }) {
    return chunkPages([text], chunkWords: chunkWords, overlapWords: overlapWords)
        .map((c) => c.text)
        .toList();
  }

  static List<String> splitWords(String text) =>
      text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

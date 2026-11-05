// File: lib/services/vector_math.dart
// Cosine similarity & pencarian top-k untuk RAG.

import 'dart:math' as math;

class VectorMath {
  /// Cosine similarity di rentang [-1, 1]. 0 jika salah satu vektor nol.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Dimensi vektor berbeda: ${a.length} vs ${b.length}');
    }
    var dot = 0.0, normA = 0.0, normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Ambil [k] item dengan skor tertinggi terhadap [query], urut menurun.
  /// Item dengan dimensi berbeda (mis. dari model embedding lain) dilewati.
  static List<ScoredItem<T>> topK<T>(
    List<double> query,
    Iterable<T> items,
    List<double> Function(T item) vectorOf, {
    int k = 3,
  }) {
    final scored = <ScoredItem<T>>[];
    for (final item in items) {
      final v = vectorOf(item);
      if (v.length != query.length) continue;
      scored.add(ScoredItem(item, cosineSimilarity(query, v)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList();
  }
}

class ScoredItem<T> {
  final T item;
  final double score;

  const ScoredItem(this.item, this.score);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/services/vector_math.dart';

void main() {
  group('cosineSimilarity', () {
    test('vektor sama = 1, tegak lurus = 0, berlawanan = -1', () {
      expect(VectorMath.cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1, 1e-9));
      expect(VectorMath.cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9));
      expect(VectorMath.cosineSimilarity([1, 1], [-1, -1]), closeTo(-1, 1e-9));
    });

    test('tidak bergantung panjang vektor', () {
      expect(VectorMath.cosineSimilarity([1, 2], [10, 20]), closeTo(1, 1e-9));
    });

    test('nilai contoh', () {
      // cos = (1*2 + 2*1) / (sqrt5 * sqrt5) = 0.8
      expect(VectorMath.cosineSimilarity([1, 2], [2, 1]), closeTo(0.8, 1e-9));
    });

    test('vektor nol = 0, dimensi beda = error', () {
      expect(VectorMath.cosineSimilarity([0, 0], [1, 1]), 0);
      expect(() => VectorMath.cosineSimilarity([1], [1, 2]), throwsArgumentError);
    });
  });

  test('topK mengambil 3 termirip urut menurun', () {
    final items = {
      'kucing': [0.9, 0.1, 0.0],
      'anjing': [0.8, 0.3, 0.0],
      'mobil': [0.0, 0.1, 0.9],
      'motor': [0.1, 0.0, 0.8],
      'beda-dimensi': [1.0, 0.0],
    };
    final top = VectorMath.topK<String>([1, 0.2, 0], items.keys, (k) => items[k]!, k: 3);
    expect(top.map((s) => s.item), ['kucing', 'anjing', 'motor']);
    expect(top.first.score, greaterThan(top.last.score));
  });
}

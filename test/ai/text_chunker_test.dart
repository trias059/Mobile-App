import 'package:flutter_test/flutter_test.dart';
import 'package:lisku/services/text_chunker.dart';

List<String> words(int from, int count) => [for (var i = from; i < from + count; i++) 'w$i'];

void main() {
  test('teks pendek jadi satu potongan', () {
    final chunks = TextChunker.chunkPages(['halo dunia ini   singkat']);
    expect(chunks, hasLength(1));
    expect(chunks.first.text, 'halo dunia ini singkat');
    expect(chunks.first.startPage, 1);
    expect(chunks.first.endPage, 1);
  });

  test('potongan 500 kata dengan overlap 50 kata', () {
    final chunks = TextChunker.chunkPages([words(0, 1200).join(' ')]);
    // langkah 450: [0-500), [450-950), [900-1200)
    expect(chunks.map((c) => c.wordCount), [500, 500, 300]);
    final first = chunks[0].text.split(' ');
    final second = chunks[1].text.split(' ');
    expect(first.sublist(450), second.sublist(0, 50)); // overlap 50 kata
    expect(second.first, 'w450');
    expect(chunks[2].text.split(' ').last, 'w1199');
  });

  test('ekor yang terlalu kecil digabung ke potongan sebelumnya', () {
    final chunks = TextChunker.chunkPages([words(0, 520).join(' ')]);
    expect(chunks, hasLength(1));
    expect(chunks.single.wordCount, 520);
  });

  test('nomor halaman awal & akhir dicatat, halaman kosong dilewati', () {
    final pages = [
      words(0, 300).join(' '), // hal 1
      '', // hal 2 kosong
      words(300, 300).join(' '), // hal 3
      words(600, 300).join(' '), // hal 4
    ];
    final chunks = TextChunker.chunkPages(pages);
    expect(chunks[0].startPage, 1);
    expect(chunks[0].endPage, 3);
    expect(chunks[1].startPage, 3); // mulai di w450
    expect(chunks[1].endPage, 4);
    expect(chunks.last.endPage, 4);
  });

  test('semua kata tercakup', () {
    final source = words(0, 2345);
    final chunks = TextChunker.chunkPages([source.join(' ')]);
    final covered = <String>{for (final c in chunks) ...c.text.split(' ')};
    expect(covered, source.toSet());
  });

  test('PDF kosong menghasilkan nol potongan', () {
    expect(TextChunker.chunkPages(['', '  \n ']), isEmpty);
    expect(TextChunker.chunkText(''), isEmpty);
  });

  test('parameter kustom', () {
    final chunks = TextChunker.chunkPages([words(0, 10).join(' ')], chunkWords: 4, overlapWords: 1);
    expect(chunks.map((c) => c.text), ['w0 w1 w2 w3', 'w3 w4 w5 w6', 'w6 w7 w8 w9']);
  });
}

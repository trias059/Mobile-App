// File: lib/services/pdf_text_extractor.dart
// Ekstrak teks PDF per halaman di isolate terpisah agar UI tidak macet.

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfTextExtractorService {
  /// Return teks tiap halaman (index 0 = halaman 1).
  static Future<List<String>> extractPages(Uint8List bytes) => compute(_extract, bytes);
}

List<String> _extract(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(document);
    final pages = <String>[];
    for (var i = 0; i < document.pages.count; i++) {
      try {
        pages.add(extractor.extractText(startPageIndex: i, endPageIndex: i));
      } catch (_) {
        pages.add(''); // halaman bermasalah dilewati
      }
    }
    return pages;
  } finally {
    document.dispose();
  }
}

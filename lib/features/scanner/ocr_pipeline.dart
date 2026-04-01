/// SplitSmart — ML Kit OCR text processor.
///
/// Stage 1: Uses ML Kit `TextRecognizer` to extract raw text from camera frame.
/// Stage 2: regex-based item/price extraction with confidence scoring.
/// Stage 3 (fallback): if regex yields < 2 items or avgConfidence < 0.6,
///           calls `GeminiParser.parse()` for LLM-based extraction.
///
/// Confidence rules:
///  - Item name matched by strong pattern (word boundary, capitalized): 0.9
///  - Price matched by tight pattern (₹ / Rs prefix or .xx suffix): 0.9
///  - Price matched loosely (bare number, could be quantity): 0.55
///  - Gemini returns fixed 0.85 for its items

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'gemini_parser.dart';

class OcrPipeline {
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // ── Price patterns ──────────────────────────────────────────────────────────
  // Matches: ₹120, Rs.120, Rs 120, 120.00, 1,200.00
  static final _pricePattern = RegExp(
    r'(?:₹|Rs\.?\s*)(\d{1,4}(?:,\d{3})*(?:\.\d{2})?)',
    caseSensitive: false,
  );

  // Looser match — bare decimal number at end of line
  static final _loosePricePattern = RegExp(r'(\d{1,4}(?:\.\d{2}))$');

  /// Run the full OCR pipeline on [imageFile].
  /// Returns a [OcrResult] with items and raw text for debugging.
  static Future<OcrResult> process(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _recognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    final items = _extractItems(recognizedText);

    final avgConf = items.isEmpty
        ? 0.0
        : items.map((e) => e.confidence).reduce((a, b) => a + b) / items.length;

    // Fallback to Gemini if we got < 2 items or low average confidence
    if (items.length < 2 || avgConf < 0.60) {
      final geminiItems = await GeminiParser.parse(rawText);
      if (geminiItems.isNotEmpty) {
        return OcrResult(
          items: geminiItems,
          rawText: rawText,
          usedGemini: true,
        );
      }
    }

    return OcrResult(items: items, rawText: rawText, usedGemini: false);
  }

  static List<ParsedItem> _extractItems(RecognizedText recognized) {
    final items = <ParsedItem>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        // Try strong price match first
        final strongMatch = _pricePattern.firstMatch(text);
        if (strongMatch != null) {
          final priceStr =
              strongMatch.group(1)!.replaceAll(',', '');
          final price = double.tryParse(priceStr);
          if (price == null || price <= 0) continue;

          // Item name: everything before the price match
          final nameEnd = strongMatch.start;
          final name =
              text.substring(0, nameEnd).trim().replaceAll(RegExp(r'\s+'), ' ');
          if (name.isEmpty) continue;
          if (name.length < 2) continue; // noise filter

          items.add(ParsedItem(
            name: _cleanName(name),
            price: price,
            confidence: 0.90,
          ));
          continue;
        }

        // Loose price match — bare decimal
        final looseMatch = _loosePricePattern.firstMatch(text);
        if (looseMatch != null) {
          final price = double.tryParse(looseMatch.group(1)!);
          if (price == null || price <= 0) continue;

          final nameEnd = looseMatch.start;
          final name = text.substring(0, nameEnd).trim();
          if (name.length < 3) continue;

          items.add(ParsedItem(
            name: _cleanName(name),
            price: price,
            confidence: 0.55, // amber — loose match
          ));
        }
      }
    }

    // Deduplicate by exact name
    final seen = <String>{};
    return items.where((i) => seen.add(i.name.toLowerCase())).toList();
  }

  static String _cleanName(String raw) {
    return raw
        .replaceAll(RegExp(r'[^\w\s\-&\'']'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static void dispose() => _recognizer.close();
}

class OcrResult {
  final List<ParsedItem> items;
  final String rawText;
  final bool usedGemini;

  const OcrResult({
    required this.items,
    required this.rawText,
    required this.usedGemini,
  });
}

/// SplitSmart — Receipt OCR pipeline.
///
/// Two-stage pipeline with graceful degradation:
///
///   Stage 1 [PRIMARY — online]:
///     image bytes → GeminiParser.parseImage() → List<ParsedItem>
///     • Gemini 2.0 Flash sees the full image with spatial layout.
///     • Handles Indian receipts: qty×price tables, CGST/SGST ignorance,
///       Hindi+English item names, crumpled or low-light photos.
///
///   Stage 2 [FALLBACK — offline / Gemini unavailable]:
///     image File → ML Kit TextRecognizer → rawText
///       → regex extraction (tight: 0.90 conf, loose: 0.55 conf)
///       → if items < 2 or avgConf < 0.60:
///             GeminiParser.parse(rawText) [text-only LLM]
///
/// Callers receive an [OcrResult] with items, rawText, and a [OcrSource] enum
/// so the review screen can badge the result appropriately.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'gemini_parser.dart';

// On-device ML Kit recogniser — kept as a singleton to avoid re-loading model.
final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

class OcrPipeline {
  // ── Price patterns ───────────────────────────────────────────────────────────
  // Tight: ₹120 / Rs.120 / Rs 120 / 1,200.00 (requires currency prefix or decimals)
  static final _priceStrong = RegExp(
    r'(?:₹|Rs\.?\s*)(\d{1,4}(?:,\d{3})*(?:\.\d{2})?)',
    caseSensitive: false,
  );
  // Loose: bare decimal at end of line (e.g. "Chicken Tikka   250.00")
  static final _priceLoose = RegExp(r'(\d{1,4}(?:\.\d{2}))$');

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Run the full pipeline on [imageFile].
  ///
  /// [imageFile] is the raw camera/pick file.  The pipeline compresses it
  /// internally before sending to Gemini — no pre-compression needed by caller.
  static Future<OcrResult> process(File imageFile) async {
    // ── Stage 1: Gemini Vision (primary) ────────────────────────────────────
    try {
      final compressedBytes = await _compress(imageFile);
      if (compressedBytes != null && compressedBytes.isNotEmpty) {
        final geminiItems = await GeminiParser.parseImage(compressedBytes);
        if (geminiItems.isNotEmpty) {
          return OcrResult(
            items: geminiItems,
            rawText: '',
            source: OcrSource.geminiVision,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [OCR/GeminiVision] $e — falling back to ML Kit');
    }

    // ── Stage 2: ML Kit offline fallback ────────────────────────────────────
    return _mlKitFallback(imageFile);
  }

  // ── Image compression ─────────────────────────────────────────────────────

  /// Compress + resize to max 1280px on the long edge, quality 85.
  /// Returns null on failure — caller falls through to ML Kit.
  static Future<Uint8List?> _compress(File imageFile) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 1280,
        minHeight: 1280,
        quality: 85,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
    } catch (e) {
      debugPrint('⚠️ [OCR/compress] $e');
      return null;
    }
  }

  // ── ML Kit fallback ───────────────────────────────────────────────────────

  static Future<OcrResult> _mlKitFallback(File imageFile) async {
    String rawText = '';
    List<ParsedItem> items = [];

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      rawText = recognized.text;
      items = _extractItemsFromBlocks(recognized);
    } catch (e) {
      debugPrint('⚠️ [OCR/MLKit] $e');
    }

    final avgConf = items.isEmpty
        ? 0.0
        : items.map((e) => e.confidence).reduce((a, b) => a + b) / items.length;

    // Sub-threshold: try Gemini text path as additional fallback
    if (items.length < 2 || avgConf < 0.60) {
      try {
        final geminiTextItems = await GeminiParser.parse(rawText);
        if (geminiTextItems.isNotEmpty) {
          return OcrResult(
            items: geminiTextItems,
            rawText: rawText,
            source: OcrSource.geminiText,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [OCR/GeminiText] $e');
      }
    }

    return OcrResult(
      items: items,
      rawText: rawText,
      source: OcrSource.mlKitRegex,
    );
  }

  // ── ML Kit block → regex extraction ──────────────────────────────────────

  static List<ParsedItem> _extractItemsFromBlocks(RecognizedText recognized) {
    final items = <ParsedItem>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;

        // Try strong price match first
        final strongMatch = _priceStrong.firstMatch(text);
        if (strongMatch != null) {
          final priceStr = strongMatch.group(1)!.replaceAll(',', '');
          final price = double.tryParse(priceStr);
          if (price == null || price <= 0) continue;

          final name = text.substring(0, strongMatch.start).trim();
          if (name.length < 2) continue;

          items.add(ParsedItem(
            name: _cleanName(name),
            price: price,
            confidence: 0.90,
          ));
          continue;
        }

        // Loose match — bare decimal at end of line
        final looseMatch = _priceLoose.firstMatch(text);
        if (looseMatch != null) {
          final price = double.tryParse(looseMatch.group(1)!);
          if (price == null || price <= 0) continue;

          final name = text.substring(0, looseMatch.start).trim();
          if (name.length < 3) continue;

          items.add(ParsedItem(
            name: _cleanName(name),
            price: price,
            confidence: 0.55,
          ));
        }
      }
    }

    // Deduplicate by exact lowercase name
    final seen = <String>{};
    return items.where((i) => seen.add(i.name.toLowerCase())).toList();
  }

  static String _cleanName(String raw) {
    return raw
        .replaceAll(RegExp(r"[^\w\s\-&\'']"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static void dispose() => _recognizer.close();
}

// ─── Result types ─────────────────────────────────────────────────────────────

enum OcrSource {
  geminiVision, // image sent directly to Gemini — most accurate
  geminiText,   // ML Kit text forwarded to Gemini
  mlKitRegex,   // on-device regex only (offline)
}

class OcrResult {
  final List<ParsedItem> items;
  final String rawText;
  final OcrSource source;

  const OcrResult({
    required this.items,
    required this.rawText,
    required this.source,
  });

  /// Legacy accessor — true when any Gemini path was used.
  bool get usedGemini =>
      source == OcrSource.geminiVision || source == OcrSource.geminiText;

  String get sourceBadge => switch (source) {
        OcrSource.geminiVision => '✦ Gemini Vision',
        OcrSource.geminiText   => '✦ Gemini AI',
        OcrSource.mlKitRegex   => '⚡ ML Kit (offline)',
      };
}

/// SplitSmart — Gemini Vision receipt parser.
///
/// Primary path: sends the raw image bytes (JPEG) directly to Gemini 2.0 Flash
/// as a multimodal [DataPart].  Gemini sees the full spatial layout — column
/// alignment, qty × price, GST lines — and returns structured JSON.
///
/// Fallback (text-only): [parse] accepts raw OCR text for offline/ML Kit mode.
///
/// Confidence model:
///   Vision path  → 0.90 (Gemini saw the image directly)
///   Text path    → 0.80 (Gemini is reasoning from OCR text)
///   Regex path   → 0.90 (tight pattern) / 0.55 (loose match)

import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

// ─── Shared prompt rules ──────────────────────────────────────────────────────
const _kRules = '''
You are an expert Indian receipt parser.

Rules — follow exactly:
1. Return ONLY valid JSON with this schema:
   {"items": [{"name": "...", "price": 99.50, "qty": 1}, ...]}
2. Prices must be bare numbers in INR (strip ₹ / Rs symbols, no currency prefix).
3. "qty" defaults to 1 if not printed. If qty × unit_price appears, store the LINE TOTAL in "price".
4. IGNORE completely: GST, CGST, SGST, taxes, service charge, packaging,
   subtotal, grand total, totals, discounts, coupons, loyalty points,
   "Amount Payable", "Balance Due", restaurant name, table number, date/time.
5. Only include individual purchased LINE ITEMS (food, drinks, services sold).
6. If you cannot find any items, return {"items": []}.
7. No markdown, no explanation — pure JSON only.
''';

class GeminiParser {
  // Injected at build time: flutter run --dart-define=GEMINI_API_KEY=your_key
  static const _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // gemini-2.0-flash: same cost tier as 1.5-flash, better table parsing
  static const _modelName = 'gemini-2.0-flash';

  // ── Vision path (primary) ──────────────────────────────────────────────────

  /// Parse a receipt image [bytes] (JPEG/PNG) directly via Gemini Vision.
  ///
  /// Returns an empty list on any failure — callers must handle gracefully.
  static Future<List<ParsedItem>> parseImage(Uint8List bytes) async {
    if (_apiKey.isEmpty) return [];
    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,    // extract facts, not creativity
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );

      final imagePart = DataPart('image/jpeg', bytes);
      final promptPart = TextPart(
        '$_kRules\n\nAnalyze the receipt image above and extract all line items.',
      );

      final response = await model
          .generateContent([Content.multi([promptPart, imagePart])])
          .timeout(const Duration(seconds: 20));

      return _parseJson(response.text, confidence: 0.90);
    } catch (_) {
      return [];
    }
  }

  // ── Text-only path (offline / ML Kit fallback) ────────────────────────────

  /// Parse raw OCR text extracted by ML Kit.
  ///
  /// Less accurate than [parseImage] because spatial layout is lost, but still
  /// far better than regex alone for messy/non-standard receipts.
  static Future<List<ParsedItem>> parse(String rawOcrText) async {
    if (rawOcrText.trim().isEmpty || _apiKey.isEmpty) return [];
    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );

      final response = await model.generateContent([
        Content.text('$_kRules\n\nReceipt text:\n$rawOcrText'),
      ]).timeout(const Duration(seconds: 15));

      return _parseJson(response.text, confidence: 0.80);
    } catch (_) {
      return [];
    }
  }

  // ── JSON → ParsedItem[] ───────────────────────────────────────────────────

  static List<ParsedItem> _parseJson(String? text, {required double confidence}) {
    if (text == null || text.trim().isEmpty) return [];
    try {
      // Gemini occasionally wraps JSON in markdown code fences — strip them.
      final cleaned = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawItems = parsed['items'] as List<dynamic>? ?? [];

      return rawItems.where((item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final name = (item['name'] as String?)?.trim() ?? '';
        return price > 0 && name.isNotEmpty;
      }).map((item) {
        return ParsedItem(
          name: (item['name'] as String).trim(),
          price: (item['price'] as num).toDouble(),
          qty: (item['qty'] as num?)?.toInt() ?? 1,
          confidence: confidence,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

// ─── ParsedItem ────────────────────────────────────────────────────────────────

/// A single receipt line item parsed by [GeminiParser] or ML Kit regex.
class ParsedItem {
  final String name;

  /// Line total in INR (= qty × unit price if qty > 1).
  final double price;

  /// Number of units. Defaults to 1.
  final int qty;

  /// 0.0–1.0 confidence score.
  /// Vision path: 0.90. Text path: 0.80. Regex tight: 0.90. Regex loose: 0.55.
  /// Values < 0.7 are highlighted amber in the review screen.
  final double confidence;

  const ParsedItem({
    required this.name,
    required this.price,
    this.qty = 1,
    required this.confidence,
  });

  bool get isLowConfidence => confidence < 0.7;

  ParsedItem copyWith({
    String? name,
    double? price,
    int? qty,
    double? confidence,
  }) {
    return ParsedItem(
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      confidence: confidence ?? this.confidence,
    );
  }
}

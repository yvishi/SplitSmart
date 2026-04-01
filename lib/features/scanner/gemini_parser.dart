/// SplitSmart — Gemini Flash LLM receipt parser.
///
/// Used as a fallback when ML Kit regex extraction fails or confidence < 0.7.
/// Single API call with a tight prompt — returns structured JSON items + prices.
///
/// Call flow:
///   ML Kit extracts raw text → GeminiParser.parse(rawText) → List<ParsedItem>
///   On failure → returns empty list so we gracefully degrade to manual entry.

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiParser {
  // Replace with your actual Gemini API key (store in .env / flutter_dotenv in prod)
  static const _apiKey = 'AIzaSyAZldURA7SHofJwJZx-6fPfl0gvYkLt2xA';
  static const _model = 'gemini-1.5-flash-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Parse raw OCR text into structured items.
  /// Returns empty list on any failure — caller must handle gracefully.
  static Future<List<ParsedItem>> parse(String rawOcrText) async {
    if (rawOcrText.trim().isEmpty) return [];

    final prompt = '''
You are a receipt parser. Extract line items and prices from this raw receipt text.

Rules:
- Return ONLY valid JSON, no markdown, no explanation.
- Format: {"items": [{"name": "Item Name", "price": 99.00}, ...]}
- Prices must be numbers (no currency symbols).
- Ignore totals, taxes, subtotals, discounts — only line items.
- If you cannot parse, return {"items": []}

Receipt text:
$rawOcrText
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,       // low — we want facts, not creativity
                'maxOutputTokens': 1024,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return [];

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final rawItems = parsed['items'] as List<dynamic>? ?? [];

      return rawItems.map((item) {
        return ParsedItem(
          name: item['name'] as String? ?? 'Unknown Item',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          confidence: 0.85, // LLM-parsed items get a fixed confidence of 0.85
        );
      }).toList();
    } catch (_) {
      // Network error, timeout, parse failure — always degrade gracefully
      return [];
    }
  }
}

/// A single parsed receipt item returned by [GeminiParser] or ML Kit regex.
class ParsedItem {
  final String name;
  final double price;

  /// 0.0–1.0. ML Kit regex: variable. Gemini: 0.85. Manual: 1.0.
  /// Values < 0.7 get amber highlight in the item list.
  final double confidence;

  const ParsedItem({
    required this.name,
    required this.price,
    required this.confidence,
  });

  bool get isLowConfidence => confidence < 0.7;

  ParsedItem copyWith({String? name, double? price, double? confidence}) {
    return ParsedItem(
      name: name ?? this.name,
      price: price ?? this.price,
      confidence: confidence ?? this.confidence,
    );
  }
}

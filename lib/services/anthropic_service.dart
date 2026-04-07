import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AnthropicService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  static const _version = '2023-06-01';

  final String apiKey;
  AnthropicService(this.apiKey);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _version,
        'anthropic-dangerous-direct-browser-access': 'true',
      };

  // ── Scan image ───────────────────────────────────────────────────
  Future<ScanResult> scanImage(Uint8List imageBytes, String mediaType) async {
    const prompt = '''You are a professional nutritionist. Analyse this meal photo carefully.
Respond ONLY in this exact JSON (no markdown):
{"meal_name":"<short name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';

    final b64 = base64Encode(imageBytes);
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': b64,
              }
            },
            {'type': 'text', 'text': prompt}
          ]
        }
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    return _parseResponse(res);
  }

  // ── Scan text description ────────────────────────────────────────
  Future<ScanResult> scanText(String description) async {
    final prompt =
        '''You are a professional nutritionist. Estimate the nutritional content for this meal description: "$description"
Respond ONLY in this exact JSON (no markdown):
{"meal_name":"<short name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': prompt
        }
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    return _parseResponse(res);
  }

  ScanResult _parseResponse(http.Response res) {
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(clean) as Map<String, dynamic>;
    return ScanResult.fromJson(parsed);
  }

  // ── Coach chat ───────────────────────────────────────────────────
  Future<String> chat({
    required List<ChatMessage> history,
    required String userMessage,
    required String systemPrompt,
  }) async {
    final messages = [
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 1024,
      'system': systemPrompt,
      'messages': messages,
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/ai_provider.dart';
import 'ai_vision_settings_service.dart';
import 'app_logger.dart';
import 'secure_key_store.dart';

const _kLogTag = 'VisionService';

const _kPrompt =
    'You are looking at a single item photographed for a home inventory app. '
    'Identify what the item is. Respond with ONLY a JSON array of up to 5 short, '
    'specific guesses for the item name, ordered from most to least likely, e.g. '
    '["cordless drill","power drill","impact driver","electric screwdriver","tool"]. '
    'No other text, no markdown, no explanation.';

/// Sends a photo directly to the user's own AI provider (Gemini, Claude, or
/// ChatGPT) over HTTPS to identify the item. No Bokses server is involved —
/// this is a direct, encrypted, device-to-provider connection made only when
/// the user taps to identify an item. The API key is read from
/// [SecureKeyStore] (encrypted browser storage) and never logged.
class VisionService {
  static Future<bool> isAvailable() => AiVisionSettingsService.isConfigured();

  static Future<List<String>> identifyItem({required String imagePath}) async {
    final provider = await AiVisionSettingsService.activeProvider();
    if (provider == null) {
      AppLogger.log(_kLogTag, 'identifyItem aborted: no active provider set.');
      throw Exception(
        'No AI provider configured. Add an API key in Settings > AI Provider.',
      );
    }
    final def = aiProviderDef(provider);
    final apiKey = await SecureKeyStore.getKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      AppLogger.log(_kLogTag, 'identifyItem aborted: no key saved for ${def.displayName}.');
      throw Exception('No API key saved for ${def.displayName}.');
    }

    AppLogger.log(_kLogTag, 'identifyItem start — provider=${def.displayName} model=${def.model}');

    try {
      final imageBytes = await _loadAndCompressImage(imagePath);
      final base64Image = base64Encode(imageBytes);
      AppLogger.log(_kLogTag, 'image compressed — ${imageBytes.length} bytes, base64 len=${base64Image.length}');

      final guesses = switch (provider) {
        AiProvider.gemini => await _identifyGemini(base64Image, apiKey),
        AiProvider.claude => await _identifyClaude(base64Image, apiKey),
        AiProvider.openai => await _identifyOpenAi(base64Image, apiKey),
      };

      AppLogger.log(_kLogTag, 'identifyItem success — guesses=$guesses');
      return guesses;
    } catch (e, st) {
      AppLogger.logError(_kLogTag, 'identifyItem failed (${def.displayName}): $e', st);
      rethrow;
    }
  }

  /// Downscales/compresses before upload so as little data as possible
  /// leaves the device — smaller payload, faster request, lower cost.
  static Future<Uint8List> _loadAndCompressImage(String imagePath) async {
    Uint8List raw;
    if (imagePath.startsWith('data:')) {
      final comma = imagePath.indexOf(',');
      raw = base64Decode(imagePath.substring(comma + 1));
    } else if (imagePath.startsWith('http') || imagePath.startsWith('blob:')) {
      // Web-search results and in-browser captures are URLs, not bytes.
      raw = await http.readBytes(Uri.parse(imagePath));
    } else {
      throw Exception('Unsupported image source: $imagePath');
    }

    final decoded = img.decodeImage(raw);
    if (decoded == null) throw Exception('Failed to decode image.');

    const maxDim = 768;
    img.Image resized = decoded;
    if (decoded.width > maxDim || decoded.height > maxDim) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDim)
          : img.copyResize(decoded, height: maxDim);
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  static Future<List<String>> _identifyGemini(
    String base64Image,
    String apiKey,
  ) async {
    const def = kGeminiProvider;
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${def.model}:generateContent?key=$apiKey',
    );
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _kPrompt},
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Image,
                    },
                  },
                ],
              },
            ],
            'generationConfig': {'temperature': 0.2},
          }),
        )
        .timeout(const Duration(seconds: 30));
    _logResponse(def.displayName, resp);
    _checkResponse(resp, def.displayName);

    final data = jsonDecode(resp.body);
    final candidate = data['candidates']?[0];
    final text = candidate?['content']?['parts']?[0]?['text'] as String?;
    if (text == null) {
      final finishReason = candidate?['finishReason'];
      throw Exception(
        '${def.displayName} returned no result'
        '${finishReason != null ? ' (finishReason: $finishReason)' : ''}.',
      );
    }
    return _parseGuesses(text);
  }

  static Future<List<String>> _identifyClaude(
    String base64Image,
    String apiKey,
  ) async {
    const def = kClaudeProvider;
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': def.model,
            'max_tokens': 256,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/jpeg',
                      'data': base64Image,
                    },
                  },
                  {'type': 'text', 'text': _kPrompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));
    _logResponse(def.displayName, resp);
    _checkResponse(resp, def.displayName);

    final data = jsonDecode(resp.body);
    final content = data['content'] as List?;
    final text = (content != null && content.isNotEmpty)
        ? content.first['text'] as String?
        : null;
    if (text == null) throw Exception('${def.displayName} returned no result.');
    return _parseGuesses(text);
  }

  static Future<List<String>> _identifyOpenAi(
    String base64Image,
    String apiKey,
  ) async {
    const def = kOpenAiProvider;
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': def.model,
            'max_tokens': 256,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': _kPrompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));
    _logResponse(def.displayName, resp);
    _checkResponse(resp, def.displayName);

    final data = jsonDecode(resp.body);
    final text = data['choices']?[0]?['message']?['content'] as String?;
    if (text == null) throw Exception('${def.displayName} returned no result.');
    return _parseGuesses(text);
  }

  static void _logResponse(String providerName, http.Response resp) {
    const maxLen = 4000;
    final body = resp.body.length > maxLen
        ? '${resp.body.substring(0, maxLen)}… [truncated]'
        : resp.body;
    AppLogger.log(
      _kLogTag,
      '$providerName response — status=${resp.statusCode} body=$body',
    );
  }

  static void _checkResponse(http.Response resp, String providerName) {
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw Exception(
        '$providerName rejected the API key. Check it in Settings.',
      );
    }
    if (resp.statusCode == 429) {
      throw Exception('$providerName rate limit reached. Try again shortly.');
    }
    if (resp.statusCode != 200) {
      throw Exception('$providerName request failed (${resp.statusCode}).');
    }
  }

  static List<String> _parseGuesses(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }

    try {
      final decoded = jsonDecode(t);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .take(5)
            .toList();
      }
    } catch (_) {}

    return t
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[\-\*\d\.\)]+\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .take(5)
        .toList();
  }
}

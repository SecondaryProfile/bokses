// Tests for VisionService and the AI provider settings it depends on.
//
// VisionService calls the top-level `http` functions, so every request is
// routed to a MockClient via `http.runWithClient` — no network, no real keys.
// Secure storage and SharedPreferences use their in-memory test backends.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bokses/models/ai_provider.dart';
import 'package:bokses/services/ai_vision_settings_service.dart';
import 'package:bokses/services/app_logger.dart';
import 'package:bokses/services/secure_key_store.dart';
import 'package:bokses/services/vision_service.dart';

const _fakeKey = 'test-key-DO-NOT-LOG-1234567890';

String _pngDataUri({int width = 4, int height = 4}) {
  final png = img.encodePng(img.Image(width: width, height: height));
  return 'data:image/png;base64,${base64Encode(png)}';
}

/// Configures [provider] as active with [_fakeKey] saved for it.
Future<void> _configure(AiProvider provider) async {
  await AiVisionSettingsService.setActiveProvider(provider);
  await SecureKeyStore.saveKey(provider, _fakeKey);
}

/// Runs identifyItem with every HTTP request answered by [handler].
Future<List<String>> _identify(
  Future<http.Response> Function(http.Request req) handler, {
  String? imagePath,
}) {
  return http.runWithClient(
    () => VisionService.identifyItem(imagePath: imagePath ?? _pngDataUri()),
    () => MockClient(handler),
  );
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

http.Response _geminiText(String text) => _json({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

http.Response _claudeText(String text) => _json({
      'content': [
        {'type': 'text', 'text': text}
      ]
    });

http.Response _openAiText(String text) => _json({
      'choices': [
        {
          'message': {'content': text}
        }
      ]
    });

/// Decodes the JPEG a provider request carried, whichever provider it was.
img.Image _sentImage(Map<String, dynamic> body) {
  String? b64;
  final contents = body['contents'] as List?;
  if (contents != null) {
    final parts = contents.first['parts'] as List;
    b64 = parts.firstWhere((p) => p['inline_data'] != null)['inline_data']
        ['data'] as String;
  } else {
    final content = (body['messages'] as List).first['content'] as List;
    final part = content.firstWhere((p) => p['type'] != 'text');
    b64 = part['type'] == 'image'
        ? part['source']['data'] as String
        : (part['image_url']['url'] as String).split(',').last;
  }
  return img.decodeJpg(base64Decode(b64))!;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AppLogger.clear();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // AiProvider definitions
  // ══════════════════════════════════════════════════════════════════════════

  group('AiProvider definitions', () {
    test('every enum value has exactly one definition', () {
      for (final p in AiProvider.values) {
        expect(kAiProviders.where((d) => d.provider == p), hasLength(1));
        expect(aiProviderDef(p).provider, p);
      }
    });

    test('every definition names a model', () {
      for (final d in kAiProviders) {
        expect(d.model, isNotEmpty, reason: d.displayName);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // SecureKeyStore / AiVisionSettingsService
  // ══════════════════════════════════════════════════════════════════════════

  group('SecureKeyStore', () {
    test('save, read, and delete a key', () async {
      await SecureKeyStore.saveKey(AiProvider.claude, 'abc');
      expect(await SecureKeyStore.getKey(AiProvider.claude), 'abc');
      expect(await SecureKeyStore.hasKey(AiProvider.claude), isTrue);

      await SecureKeyStore.deleteKey(AiProvider.claude);
      expect(await SecureKeyStore.getKey(AiProvider.claude), isNull);
      expect(await SecureKeyStore.hasKey(AiProvider.claude), isFalse);
    });

    test('keys are stored per provider', () async {
      await SecureKeyStore.saveKey(AiProvider.gemini, 'g');
      expect(await SecureKeyStore.hasKey(AiProvider.gemini), isTrue);
      expect(await SecureKeyStore.hasKey(AiProvider.openai), isFalse);
    });

    test('an empty key counts as no key', () async {
      await SecureKeyStore.saveKey(AiProvider.openai, '');
      expect(await SecureKeyStore.hasKey(AiProvider.openai), isFalse);
    });

    test('keys never land in SharedPreferences', () async {
      await SecureKeyStore.saveKey(AiProvider.claude, _fakeKey);
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        expect(prefs.get(k).toString(), isNot(contains(_fakeKey)));
      }
    });
  });

  group('AiVisionSettingsService', () {
    test('no active provider by default', () async {
      expect(await AiVisionSettingsService.activeProvider(), isNull);
      expect(await AiVisionSettingsService.isConfigured(), isFalse);
    });

    test('active provider persists and can be cleared', () async {
      await AiVisionSettingsService.setActiveProvider(AiProvider.openai);
      expect(await AiVisionSettingsService.activeProvider(), AiProvider.openai);

      await AiVisionSettingsService.setActiveProvider(null);
      expect(await AiVisionSettingsService.activeProvider(), isNull);
    });

    test('an unrecognised stored provider reads as none', () async {
      SharedPreferences.setMockInitialValues(
          {'bokses_active_ai_provider': 'onnx_xl'});
      expect(await AiVisionSettingsService.activeProvider(), isNull);
    });

    test('configured only with both an active provider and its key', () async {
      await AiVisionSettingsService.setActiveProvider(AiProvider.gemini);
      expect(await AiVisionSettingsService.isConfigured(), isFalse);

      await SecureKeyStore.saveKey(AiProvider.claude, 'wrong provider');
      expect(await AiVisionSettingsService.isConfigured(), isFalse);

      await SecureKeyStore.saveKey(AiProvider.gemini, 'k');
      expect(await AiVisionSettingsService.isConfigured(), isTrue);
      expect(await VisionService.isAvailable(), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — preconditions
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — preconditions', () {
    Future<http.Response> unreachable(http.Request _) async =>
        fail('no request should be made');

    test('throws without an active provider', () async {
      await expectLater(
        _identify(unreachable),
        throwsA(predicate((e) => '$e'.contains('No AI provider configured'))),
      );
    });

    test('throws without a key for the active provider', () async {
      await AiVisionSettingsService.setActiveProvider(AiProvider.claude);
      await expectLater(
        _identify(unreachable),
        throwsA(predicate((e) => '$e'.contains('No API key saved for Claude'))),
      );
    });

    test('rejects an unsupported image path before any request', () async {
      await _configure(AiProvider.claude);
      await expectLater(
        _identify(unreachable, imagePath: '/var/mobile/photo.jpg'),
        throwsA(predicate((e) => '$e'.contains('Unsupported image source'))),
      );
    });

    test('rejects bytes that are not an image', () async {
      await _configure(AiProvider.claude);
      final junk = 'data:image/jpeg;base64,${base64Encode(utf8.encode('no'))}';
      await expectLater(
        _identify(unreachable, imagePath: junk),
        throwsA(predicate((e) => '$e'.contains('Failed to decode image'))),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — request shape per provider
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — Gemini request', () {
    test('posts to generateContent with x-goog-api-key and an inline JPEG',
        () async {
      await _configure(AiProvider.gemini);
      late http.Request sent;

      final guesses = await _identify((req) async {
        sent = req;
        return _geminiText('["drill","driver"]');
      });

      expect(guesses, ['drill', 'driver']);
      expect(sent.method, 'POST');
      expect(sent.url.host, 'generativelanguage.googleapis.com');
      expect(sent.url.path, contains('${kGeminiProvider.model}:generateContent'));
      expect(sent.headers['x-goog-api-key'], _fakeKey);

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      final inline = (body['contents'][0]['parts'] as List)
          .firstWhere((p) => p['inline_data'] != null)['inline_data'];
      expect(inline['mime_type'], 'image/jpeg');
      expect(_sentImage(body), isNotNull);
    });
  });

  group('VisionService — Claude request', () {
    test('posts to /v1/messages with x-api-key and version headers', () async {
      await _configure(AiProvider.claude);
      late http.Request sent;

      final guesses = await _identify((req) async {
        sent = req;
        return _claudeText('["mug"]');
      });

      expect(guesses, ['mug']);
      expect(sent.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(sent.headers['x-api-key'], _fakeKey);
      expect(sent.headers['anthropic-version'], '2023-06-01');
      expect(sent.url.queryParameters, isEmpty,
          reason: 'the key belongs in a header, not the URL');

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], kClaudeProvider.model);
      final image = (body['messages'][0]['content'] as List)
          .firstWhere((p) => p['type'] == 'image');
      expect(image['source']['media_type'], 'image/jpeg');
    });
  });

  group('VisionService — OpenAI request', () {
    test('posts to chat/completions with a Bearer token', () async {
      await _configure(AiProvider.openai);
      late http.Request sent;

      final guesses = await _identify((req) async {
        sent = req;
        return _openAiText('["lamp"]');
      });

      expect(guesses, ['lamp']);
      expect(
          sent.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(sent.headers['authorization'], 'Bearer $_fakeKey');

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], kOpenAiProvider.model);
      final image = (body['messages'][0]['content'] as List)
          .firstWhere((p) => p['type'] == 'image_url');
      expect(image['image_url']['url'], startsWith('data:image/jpeg;base64,'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — image handling
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — image handling', () {
    Future<img.Image> sentImageFor(String imagePath) async {
      await _configure(AiProvider.claude);
      late Map<String, dynamic> body;
      await _identify((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _claudeText('["x"]');
      }, imagePath: imagePath);
      return _sentImage(body);
    }

    test('downscales a wide image so its long edge is 768px', () async {
      final sent = await sentImageFor(_pngDataUri(width: 1600, height: 800));
      expect(sent.width, 768);
      expect(sent.height, 384);
    });

    test('downscales a tall image so its long edge is 768px', () async {
      final sent = await sentImageFor(_pngDataUri(width: 500, height: 1000));
      expect(sent.height, 768);
      expect(sent.width, 384);
    });

    test('never upscales a small image', () async {
      final sent = await sentImageFor(_pngDataUri(width: 40, height: 30));
      expect(sent.width, 40);
      expect(sent.height, 30);
    });

    test('fetches an http image before sending it on', () async {
      await _configure(AiProvider.claude);
      final png = img.encodePng(img.Image(width: 10, height: 10));
      final requests = <String>[];

      final guesses = await _identify((req) async {
        requests.add('${req.method} ${req.url.host}');
        if (req.method == 'GET') {
          return http.Response.bytes(Uint8List.fromList(png), 200);
        }
        return _claudeText('["web thing"]');
      }, imagePath: 'https://images.example.com/thing.png');

      expect(guesses, ['web thing']);
      expect(requests,
          ['GET images.example.com', 'POST api.anthropic.com']);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — response parsing
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — response parsing', () {
    Future<List<String>> parse(String modelText) async {
      await _configure(AiProvider.openai);
      return _identify((_) async => _openAiText(modelText));
    }

    test('plain JSON array', () async {
      expect(await parse('["a","b"]'), ['a', 'b']);
    });

    test('JSON wrapped in a ```json fence', () async {
      expect(await parse('```json\n["hammer","mallet"]\n```'),
          ['hammer', 'mallet']);
    });

    test('keeps at most 5 guesses', () async {
      expect(await parse('["1","2","3","4","5","6","7"]'), hasLength(5));
    });

    test('trims guesses and drops blank ones', () async {
      expect(await parse('["  saw ", "", "   ", "plane"]'), ['saw', 'plane']);
    });

    test('falls back to a numbered or bulleted list', () async {
      expect(await parse('1. cordless drill\n2) driver\n- bit set\n* case'),
          ['cordless drill', 'driver', 'bit set', 'case']);
    });

    test('non-string JSON entries are stringified', () async {
      expect(await parse('[42, "box"]'), ['42', 'box']);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — error handling
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — HTTP errors', () {
    Future<void> expectError(int status, String message) async {
      await _configure(AiProvider.gemini);
      await expectLater(
        _identify((_) async => _json({'error': 'nope'}, status)),
        throwsA(predicate((e) => '$e'.contains(message))),
      );
    }

    test('401 means the key was rejected',
        () => expectError(401, 'Gemini rejected the API key'));
    test('403 means the key was rejected',
        () => expectError(403, 'Gemini rejected the API key'));
    test('429 means rate limited',
        () => expectError(429, 'Gemini rate limit reached'));
    test('other non-200s report the status code',
        () => expectError(503, 'Gemini request failed (503)'));
  });

  group('VisionService — empty results', () {
    test('Gemini with no text reports the finishReason', () async {
      await _configure(AiProvider.gemini);
      await expectLater(
        _identify((_) async => _json({
              'candidates': [
                {'finishReason': 'SAFETY'}
              ]
            })),
        throwsA(predicate((e) =>
            '$e'.contains('Gemini returned no result') &&
            '$e'.contains('SAFETY'))),
      );
    });

    test('Claude with empty content', () async {
      await _configure(AiProvider.claude);
      await expectLater(
        _identify((_) async => _json({'content': []})),
        throwsA(predicate((e) => '$e'.contains('Claude returned no result'))),
      );
    });

    test('OpenAI with no choices', () async {
      await _configure(AiProvider.openai);
      await expectLater(
        _identify((_) async => _json({'choices': []})),
        throwsA(predicate((e) => '$e'.contains('ChatGPT returned no result'))),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // VisionService — the API key must never reach the debug log
  // ══════════════════════════════════════════════════════════════════════════

  group('VisionService — key hygiene', () {
    for (final provider in AiProvider.values) {
      test('${provider.name}: key is never part of the request URL', () async {
        await _configure(provider);
        late Uri url;
        await expectLater(
          _identify((req) async {
            url = req.url;
            return _json({}, 500);
          }),
          throwsException,
        );
        expect(url.toString(), isNot(contains(_fakeKey)));
      });

      test('${provider.name}: key absent from log after success', () async {
        await _configure(provider);
        final ok = switch (provider) {
          AiProvider.gemini => _geminiText('["x"]'),
          AiProvider.claude => _claudeText('["x"]'),
          AiProvider.openai => _openAiText('["x"]'),
        };
        await _identify((_) async => ok);

        final log = await AppLogger.readLog();
        expect(log, contains('identifyItem success'));
        expect(log, isNot(contains(_fakeKey)));
      });

      test('${provider.name}: key absent from log after an HTTP error',
          () async {
        await _configure(provider);
        await expectLater(
            _identify((_) async => _json({}, 500)), throwsException);

        final log = await AppLogger.readLog();
        expect(log, contains('identifyItem failed'));
        expect(log, isNot(contains(_fakeKey)));
      });

      test('${provider.name}: key absent from log after a network failure',
          () async {
        await _configure(provider);
        await expectLater(
          _identify((req) async =>
              throw http.ClientException('connection reset', req.url)),
          throwsA(isA<http.ClientException>()),
        );

        final log = await AppLogger.readLog();
        expect(log, contains('identifyItem failed'));
        expect(log, isNot(contains(_fakeKey)));
      });
    }
  });
}

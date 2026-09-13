import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ai_provider.dart';

/// Stores AI provider API keys encrypted at rest. On web the backing store is
/// AES-encrypted `localStorage`, keyed per origin — it keeps keys out of plain
/// SharedPreferences and app logs, but it is only as private as the browser
/// profile, so a shared machine is a shared key.
class SecureKeyStore {
  static const _storage = FlutterSecureStorage();

  static String _keyFor(AiProvider provider) => 'bokses_ai_key_${provider.name}';

  static Future<void> saveKey(AiProvider provider, String key) async {
    await _storage.write(key: _keyFor(provider), value: key);
  }

  static Future<String?> getKey(AiProvider provider) async {
    return _storage.read(key: _keyFor(provider));
  }

  static Future<void> deleteKey(AiProvider provider) async {
    await _storage.delete(key: _keyFor(provider));
  }

  static Future<bool> hasKey(AiProvider provider) async {
    final key = await getKey(provider);
    return key != null && key.isNotEmpty;
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';
import 'secure_key_store.dart';

class AiVisionSettingsService {
  static const _activeProviderKey = 'bokses_active_ai_provider';

  static Future<AiProvider?> activeProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_activeProviderKey);
    if (name == null) return null;
    try {
      return AiProvider.values.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setActiveProvider(AiProvider? provider) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider == null) {
      await prefs.remove(_activeProviderKey);
    } else {
      await prefs.setString(_activeProviderKey, provider.name);
    }
  }

  /// Whether an active provider is selected and has a saved API key.
  static Future<bool> isConfigured() async {
    final provider = await activeProvider();
    if (provider == null) return false;
    return SecureKeyStore.hasKey(provider);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _cvKey = 'cv_enabled';
  static const _darkModeKey = 'is_dark_mode';

  static Future<bool> getIsDarkMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_darkModeKey) ?? true;
  }

  static Future<void> setIsDarkMode(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_darkModeKey, value);
  }

  static Future<bool> getCvEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_cvKey) ?? false;
  }

  static Future<void> setCvEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_cvKey, value);
  }

  static const _themePresetKey = 'theme_preset';

  static Future<int> getThemePreset() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_themePresetKey) ?? 0;
  }

  static Future<void> setThemePreset(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_themePresetKey, value);
  }

  static const _talkSilenceMsKey = 'talk_silence_ms';
  static const _talkReadBackKey = 'talk_read_back';
  static const defaultTalkSilenceMs = 1500;

  static Future<int> getTalkSilenceMs() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_talkSilenceMsKey) ?? defaultTalkSilenceMs;
  }

  static Future<void> setTalkSilenceMs(int ms) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_talkSilenceMsKey, ms);
  }

  static Future<bool> getTalkReadBack() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_talkReadBackKey) ?? false;
  }

  static Future<void> setTalkReadBack(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_talkReadBackKey, value);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

enum AppBgType { none, gradient, image, solid }

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

  static const _loadAllContentKey = 'load_all_content';

  static Future<bool> getLoadAllContent() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_loadAllContentKey) ?? true;
  }

  static Future<void> setLoadAllContent(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_loadAllContentKey, value);
  }

  // AutoBoks success count — intentionally uses a new key (not the old
  // bokstalk_success_count) so existing users see the updated intro dialog.
  static const _autoBoksSuccessKey = 'autoboks_success_count';

  static Future<int> getAutoBoksSuccessCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_autoBoksSuccessKey) ?? 0;
  }

  static Future<void> incrementAutoBoksSuccessCount() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
        _autoBoksSuccessKey, (p.getInt(_autoBoksSuccessKey) ?? 0) + 1);
  }

  static const _autoBoksCameraKey = 'autoboks_camera_enabled';

  static Future<bool> getAutoBoksCameraEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoBoksCameraKey) ?? true;
  }

  static Future<void> setAutoBoksCameraEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoBoksCameraKey, value);
  }

  // ── Background ───────────────────────────────────────────────
  static const _bgTypeKey = 'bg_type';
  static const _bgImageKey = 'bg_image';
  static const _bgBlurKey = 'bg_blur';
  static const _bgColorKey = 'bg_color';

  static Future<AppBgType> getBackgroundType() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString(_bgTypeKey) ?? 'none';
    return AppBgType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppBgType.none,
    );
  }

  static Future<void> setBackgroundType(AppBgType type) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_bgTypeKey, type.name);
  }

  static Future<String?> getBackgroundImage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_bgImageKey);
  }

  static Future<void> setBackgroundImage(String? dataUri) async {
    final p = await SharedPreferences.getInstance();
    if (dataUri == null) {
      await p.remove(_bgImageKey);
    } else {
      await p.setString(_bgImageKey, dataUri);
    }
  }

  static Future<double> getBackgroundBlur() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_bgBlurKey) ?? 10.0;
  }

  static Future<void> setBackgroundBlur(double value) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_bgBlurKey, value);
  }

  static Future<int> getBackgroundColor() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_bgColorKey) ?? 0xFF0C0C0E;
  }

  static Future<void> setBackgroundColor(int argb) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_bgColorKey, argb);
  }
}

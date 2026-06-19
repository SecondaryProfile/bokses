import 'package:flutter/material.dart';
import '../constants.dart';

class ThemePreset {
  final String name;
  final Color primary;
  final Color accent;
  const ThemePreset({required this.name, required this.primary, required this.accent});
}

class AppTheme {
  // ── Theme presets ─────────────────────────────────────────
  static const presets = [
    ThemePreset(name: 'Ocean',    primary: Color(0xFF3A7BF7), accent: Color(0xFFE8394A)),
    ThemePreset(name: 'Midnight', primary: Color(0xFF5C6BC0), accent: Color(0xFF26C6DA)),
    ThemePreset(name: 'Forest',   primary: Color(0xFF27AE60), accent: Color(0xFFF4A223)),
    ThemePreset(name: 'Sunset',   primary: Color(0xFFFF6B35), accent: Color(0xFF9B59B6)),
    ThemePreset(name: 'Rose',     primary: Color(0xFFE91E8C), accent: Color(0xFF00ACC1)),
    ThemePreset(name: 'Ember',    primary: Color(0xFFE53935), accent: Color(0xFFFFB300)),
    ThemePreset(name: 'Violet',   primary: Color(0xFF7C3AED), accent: Color(0xFF10B981)),
    ThemePreset(name: 'Slate',    primary: Color(0xFF546E7A), accent: Color(0xFFFF7043)),
  ];

  // ── Active theme state ────────────────────────────────────
  static bool _isDark = true;
  static int _presetIndex = 0;

  static final ValueNotifier<bool> modeNotifier = ValueNotifier(true);
  static final ValueNotifier<int> presetNotifier = ValueNotifier(0);
  static final ValueNotifier<int> bgNotifier = ValueNotifier(0);
  static void notifyBgChanged() => bgNotifier.value++;

  static void setMode(bool dark) {
    _isDark = dark;
    modeNotifier.value = dark;
  }

  static void setPreset(int index) {
    _presetIndex = index.clamp(0, presets.length - 1);
    presetNotifier.value = _presetIndex;
  }

  static int get presetIndex => _presetIndex;

  // ── Brand color getters ───────────────────────────────────
  static Color get boksBlue => presets[_presetIndex].primary;
  static Color get boksRed  => presets[_presetIndex].accent;

  // ── Derived color helpers ─────────────────────────────────
  // Neutral base colors (pure, untinted)
  static const _darkBase  = Color(0xFF0C0C0E);
  static const _darkSurf  = Color(0xFF131315);
  static const _darkCard  = Color(0xFF1A1A1E);
  static const _lightBase = Color(0xFFF5F5F7);
  static const _lightSurf = Colors.white;
  static const _lightCard = Color(0xFFEEEEF2);

  static Color _bgTint(Color c, {double t = 0.07}) => Color.lerp(_darkBase, c, t)!;
  static Color _sfTint(Color c, {double t = 0.06}) => Color.lerp(_darkSurf, c, t)!;
  static Color _cdTint(Color c, {double t = 0.06}) => Color.lerp(_darkCard, c, t)!;
  static Color _bgTintL(Color c, {double t = 0.05}) => Color.lerp(_lightBase, c, t)!;
  static Color _sfTintL(Color c, {double t = 0.04}) => Color.lerp(_lightSurf, c, t)!;
  static Color _cdTintL(Color c, {double t = 0.05}) => Color.lerp(_lightCard, c, t)!;

  static Color _tintDark(Color c)  => Color.lerp(background, c, 0.20)!;
  static Color _tintLight(Color c) => Color.lerp(Colors.white, c, 0.12)!;
  static Color _bright(Color c)    => Color.lerp(Colors.white, c, 0.55)!;

  // ── Adaptive palette ──────────────────────────────────────
  static Color get background    => _isDark ? _bgTint(boksBlue)  : _bgTintL(boksBlue);
  static Color get surface       => _isDark ? _sfTint(boksBlue)  : _sfTintL(boksBlue);
  static Color get cardBg        => _isDark ? _cdTint(boksBlue)  : _cdTintL(boksBlue);
  static Color get textDark      => _isDark ? const Color(0xFFE8EEF8) : const Color(0xFF1A2240);
  static Color get textMid       => _isDark ? const Color(0xFF7A90B8) : const Color(0xFF5A6A8A);
  static Color get bubblePurple  => _isDark ? _cdTint(boksBlue, t: 0.14) : _cdTintL(boksBlue, t: 0.12);
  static Color get boksBlueLight  => _isDark ? _tintDark(boksBlue)  : _tintLight(boksBlue);
  static Color get boksRedLight   => _isDark ? _tintDark(boksRed)   : _tintLight(boksRed);
  static Color get boksBlueBright => _isDark ? _bright(boksBlue)    : boksBlue;
  static Color get boksRedBright  => _isDark ? _bright(boksRed)     : boksRed;

  // ── Theme getter ──────────────────────────────────────────
  static ThemeData get theme => _build(dark: _isDark);

  static ThemeData _build({required bool dark}) {
    final primary = presets[_presetIndex].primary;
    final accent  = presets[_presetIndex].accent;
    final bg      = dark ? _bgTint(primary)  : _bgTintL(primary);
    final surf    = dark ? _sfTint(primary)  : _sfTintL(primary);
    final card    = dark ? _cdTint(primary)  : _cdTintL(primary);
    final border  = dark ? _cdTint(primary, t: 0.14) : _cdTintL(primary, t: 0.12);
    final txtDark = dark ? const Color(0xFFE8EEF8) : const Color(0xFF1A2240);
    final txtMid  = dark ? const Color(0xFF7A90B8) : const Color(0xFF5A6A8A);
    final bright  = dark ? _bright(primary) : primary;

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: dark
          ? ColorScheme.dark(
              primary: primary,
              secondary: accent,
              surface: surf,
              onSurface: txtDark,
            )
          : ColorScheme.light(
              primary: primary,
              secondary: accent,
              surface: surf,
              onSurface: txtDark,
            ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.apply(
        fontFamily: kFontFamily,
        bodyColor: txtDark,
        displayColor: txtDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: bright,
        ),
        iconTheme: IconThemeData(color: txtDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        extendedTextStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(
          fontFamily: kFontFamily,
          color: txtMid,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(fontFamily: kFontFamily, color: txtMid),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: txtDark,
        ),
        contentTextStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14,
          color: txtMid,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          color: txtDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(
          fontFamily: kFontFamily,
          color: txtDark,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: bright,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

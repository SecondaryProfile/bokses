import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../services/ai_vision_settings_service.dart';
import '../models/ai_provider.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import 'account_screen.dart';
import 'ai_provider_screen.dart';
import 'debug_log_screen.dart';
import 'version_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Appearance
  bool _isDark = true;
  int _presetIndex = 0;

  // Background
  AppBgType _bgType = AppBgType.none;
  Uint8List? _bgImage;
  double _bgBlur = 10.0;
  int _bgColor = 0xFF0C0C0E;

  // AutoBoks
  int _talkSilenceMs = SettingsService.defaultTalkSilenceMs;
  bool _talkReadBack = false;
  bool _autoBoksCamera = true;

  // Computer Vision
  bool _cvEnabled = false;
  bool _hasAiKey = false;
  AiProvider? _activeAiProvider;

  // Performance
  bool _loadAll = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dark = await SettingsService.getIsDarkMode();
    final preset = await SettingsService.getThemePreset();
    final bgType = await SettingsService.getBackgroundType();
    final bgImageStr = await SettingsService.getBackgroundImage();
    final bgBlur = await SettingsService.getBackgroundBlur();
    final bgColor = await SettingsService.getBackgroundColor();
    final silenceMs = await SettingsService.getTalkSilenceMs();
    final readBack = await SettingsService.getTalkReadBack();
    final autoBoksCamera = await SettingsService.getAutoBoksCameraEnabled();
    final cv = await SettingsService.getCvEnabled();
    final loadAll = await SettingsService.getLoadAllContent();
    final activeProvider = await AiVisionSettingsService.activeProvider();
    final hasKey = await AiVisionSettingsService.isConfigured();
    if (!mounted) return;

    Uint8List? bgImage;
    if (bgImageStr != null && bgImageStr.startsWith('data:')) {
      try {
        bgImage = base64Decode(bgImageStr.split(',').last);
      } catch (_) {}
    }

    setState(() {
      _isDark = dark;
      _presetIndex = preset;
      _bgType = bgType;
      _bgImage = bgImage;
      _bgBlur = bgBlur;
      _bgColor = bgColor;
      _talkSilenceMs = silenceMs;
      _talkReadBack = readBack;
      _autoBoksCamera = autoBoksCamera;
      _cvEnabled = cv;
      _loadAll = loadAll;
      _hasAiKey = hasKey;
      _activeAiProvider = activeProvider;
    });
  }

  Future<void> _setBgType(AppBgType type) async {
    await SettingsService.setBackgroundType(type);
    AppTheme.notifyBgChanged();
    setState(() => _bgType = type);
  }

  Future<void> _pickBgImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 70,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    await SettingsService.setBackgroundImage(dataUri);
    AppTheme.notifyBgChanged();
    if (mounted) setState(() => _bgImage = bytes);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          // ── GENERAL ────────────────────────────────────────────────────────────
          _sectionLabel('GENERAL'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.dark_mode_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Dark Mode',
              trailing: Switch(
                value: _isDark,
                activeThumbColor: AppTheme.boksBlue,
                activeTrackColor: AppTheme.boksBlueLight,
                onChanged: (v) async {
                  AppTheme.setMode(v);
                  await SettingsService.setIsDarkMode(v);
                  setState(() => _isDark = v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _settingsGroup([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colour Theme',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMid,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 14,
                    children: List.generate(AppTheme.presets.length, (i) {
                      final preset = AppTheme.presets[i];
                      final selected = _presetIndex == i;
                      return GestureDetector(
                        onTap: () async {
                          AppTheme.setPreset(i);
                          await SettingsService.setThemePreset(i);
                          setState(() => _presetIndex = i);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.boksBlue
                                      : AppTheme.bubblePurple,
                                  width: selected ? 2.5 : 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Container(color: preset.primary)),
                                    Expanded(
                                        child: Container(color: preset.accent)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              preset.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: kFontFamily,
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppTheme.boksBlueBright
                                    : AppTheme.textMid,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── BACKGROUND ─────────────────────────────────────────────────────────
          _sectionLabel('BACKGROUND'),
          _settingsGroup([
            Padding(
              padding: const EdgeInsets.all(12),
              child: _bgTypeRow(),
            ),
            if (_bgType == AppBgType.gradient) ...[
              _groupDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.boksBlue, AppTheme.boksRed],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Theme gradient preview',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_bgType == AppBgType.image) ...[
              _groupDivider(),
              _settingsTile(
                icon: Icons.photo_library_rounded,
                iconColor: AppTheme.boksBlue,
                iconBg: AppTheme.boksBlueLight,
                title: _bgImage != null ? 'Change Photo' : 'Choose Photo',
                subtitle: _bgImage != null
                    ? 'Tap to replace'
                    : 'Pick from your library',
                trailing: _bgImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_bgImage!,
                            width: 44, height: 44, fit: BoxFit.cover),
                      )
                    : Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textMid),
                onTap: _pickBgImage,
              ),
              _groupDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.boksBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.blur_on_rounded,
                          color: AppTheme.boksBlue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Blur',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    Text(
                      _bgBlur < 1 ? 'Off' : '${_bgBlur.round()}',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.boksBlueBright,
                      ),
                    ),
                  ],
                ),
              ),
              Slider(
                value: _bgBlur,
                min: 0,
                max: 30,
                divisions: 30,
                activeColor: AppTheme.boksBlue,
                inactiveColor: AppTheme.boksBlueLight,
                onChanged: (v) => setState(() => _bgBlur = v),
                onChangeEnd: (v) async {
                  await SettingsService.setBackgroundBlur(v);
                  AppTheme.notifyBgChanged();
                },
              ),
              const SizedBox(height: 4),
            ],
            if (_bgType == AppBgType.solid) ...[
              _groupDivider(),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _bgPresetColors.map((c) {
                    final selected = _bgColor == c;
                    return GestureDetector(
                      onTap: () async {
                        await SettingsService.setBackgroundColor(c);
                        AppTheme.notifyBgChanged();
                        setState(() => _bgColor = c);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(c),
                          borderRadius: BorderRadius.circular(11),
                          border: selected
                              ? Border.all(color: AppTheme.boksBlue, width: 2.5)
                              : Border.all(
                                  color: AppTheme.bubblePurple, width: 1),
                        ),
                        child: selected
                            ? Icon(Icons.check_rounded,
                                color: ThemeData.estimateBrightnessForColor(
                                            Color(c)) ==
                                        Brightness.light
                                    ? Colors.black54
                                    : Colors.white,
                                size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 28),

          // ── AUTOBOKS ───────────────────────────────────────────────────────────
          _sectionLabel('AUTOBOKS'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.camera_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Camera',
              subtitle: 'Auto-capture a photo when an item is recorded',
              trailing: Switch(
                value: _autoBoksCamera,
                activeThumbColor: AppTheme.boksBlue,
                activeTrackColor: AppTheme.boksBlueLight,
                onChanged: (v) async {
                  await SettingsService.setAutoBoksCameraEnabled(v);
                  setState(() => _autoBoksCamera = v);
                },
              ),
            ),
            _groupDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.boksBlueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.timer_rounded,
                        color: AppTheme.boksBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Silence Timeout',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  Text(
                    '${(_talkSilenceMs / 1000).toStringAsFixed(1)}s',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.boksBlueBright,
                    ),
                  ),
                ],
              ),
            ),
            Slider(
              value: _talkSilenceMs.toDouble(),
              min: 500,
              max: 5000,
              divisions: 9,
              activeColor: AppTheme.boksBlue,
              inactiveColor: AppTheme.boksBlueLight,
              onChanged: (v) => setState(() => _talkSilenceMs = v.round()),
              onChangeEnd: (v) => SettingsService.setTalkSilenceMs(v.round()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Stop listening after this long with no speech',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 12,
                  color: AppTheme.textMid,
                ),
              ),
            ),
            _groupDivider(),
            _settingsTile(
              icon: Icons.volume_up_rounded,
              iconColor: AppTheme.boksRed,
              iconBg: AppTheme.boksRedLight,
              title: 'Read Back',
              subtitle: 'Speak the heard name aloud before adding',
              trailing: Switch(
                value: _talkReadBack,
                activeThumbColor: AppTheme.boksRed,
                activeTrackColor: AppTheme.boksRedLight,
                onChanged: (v) async {
                  await SettingsService.setTalkReadBack(v);
                  setState(() => _talkReadBack = v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── PERFORMANCE ────────────────────────────────────────────────────────
          _sectionLabel('PERFORMANCE'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.bolt_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Instant Load',
              subtitle:
                  'Skip fade-in animations so boxes and items appear immediately',
              trailing: Switch(
                value: _loadAll,
                activeThumbColor: AppTheme.boksBlue,
                activeTrackColor: AppTheme.boksBlueLight,
                onChanged: (v) async {
                  await SettingsService.setLoadAllContent(v);
                  setState(() => _loadAll = v);
                },
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── COMPUTER VISION ────────────────────────────────────────────────────
          _sectionLabel('COMPUTER VISION'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.auto_awesome_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'AI Provider',
              subtitle: _activeProviderLabel(),
              trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMid),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiProviderScreen()),
                );
                final provider = await AiVisionSettingsService.activeProvider();
                final hasKey = await AiVisionSettingsService.isConfigured();
                if (mounted) {
                  setState(() {
                    _hasAiKey = hasKey;
                    _activeAiProvider = provider;
                  });
                }
              },
            ),
            if (_hasAiKey) ...[
              _groupDivider(),
              _settingsTile(
                icon: Icons.memory_rounded,
                iconColor: AppTheme.boksBlue,
                iconBg: AppTheme.boksBlueLight,
                title: 'Enable AI Recognition',
                subtitle: 'Suggest item names from photos using your connected AI',
                trailing: Switch(
                  value: _cvEnabled,
                  activeThumbColor: AppTheme.boksBlue,
                  activeTrackColor: AppTheme.boksBlueLight,
                  onChanged: (v) async {
                    await SettingsService.setCvEnabled(v);
                    setState(() => _cvEnabled = v);
                  },
                ),
              ),
              if (_cvEnabled) ...[
                _groupDivider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StepRow(
                        icon: Icons.camera_alt_rounded,
                        isPrimary: true,
                        text: 'Take a photo of your item',
                      ),
                      const SizedBox(height: 10),
                      _StepRow(
                        icon: Icons.auto_awesome_rounded,
                        isPrimary: false,
                        text: 'Your AI assistant analyses it over an encrypted connection',
                      ),
                      const SizedBox(height: 10),
                      _StepRow(
                        icon: Icons.checklist_rounded,
                        isPrimary: true,
                        text: 'Pick from 5 guesses or type the name yourself',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ]),
          const SizedBox(height: 28),

          // ── ACCOUNT ─────────────────────────────────────────────────────────────
          _sectionLabel('ACCOUNT'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.person_outline_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Account',
              subtitle: 'Change your password, sign out, or manage accounts',
              trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMid),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── DIAGNOSTICS ─────────────────────────────────────────────────────────
          _sectionLabel('DIAGNOSTICS'),
          _settingsGroup([
            _settingsTile(
              icon: Icons.bug_report_outlined,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Debug Log',
              subtitle: 'View and share console output for troubleshooting',
              trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMid),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugLogScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 40),

          // ── VERSION ────────────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VersionHistoryScreen()),
            ),
            child: Center(
              child: Text(
                'v$kAppVersion',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 12,
                  color: AppTheme.textMid.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _activeProviderLabel() {
    if (_activeAiProvider == null) return 'No AI provider connected';
    final def = aiProviderDef(_activeAiProvider!);
    return '${def.displayName} connected';
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.boksBlueBright,
        ),
      ),
    );
  }

  Widget _settingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.bubblePurple, width: kBubbleBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _groupDivider() => Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.bubblePurple.withValues(alpha: 0.6),
        indent: 64,
      );

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 12,
                        color: AppTheme.textMid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }

  Widget _bgTypeRow() {
    const types = [
      (AppBgType.none, Icons.format_paint_outlined, 'Default'),
      (AppBgType.gradient, Icons.gradient_rounded, 'Gradient'),
      (AppBgType.image, Icons.image_rounded, 'Photo'),
      (AppBgType.solid, Icons.circle, 'Solid'),
    ];
    return Row(
      children: types.map((t) {
        final selected = _bgType == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => _setBgType(t.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.boksBlueLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(color: AppTheme.boksBlue, width: 1.5)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(t.$2,
                      size: 20,
                      color: selected
                          ? AppTheme.boksBlueBright
                          : AppTheme.textMid),
                  const SizedBox(height: 4),
                  Text(
                    t.$3,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppTheme.boksBlueBright
                          : AppTheme.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static const _bgPresetColors = [
    0xFF000000, // Black
    0xFFFFFFFF, // White
    0xFF2563EB, // Blue
    0xFFDC2626, // Red
    0xFF16A34A, // Green
  ];
}

// ── Step row (used in Computer Vision explanation) ─────────────────────────────

class _StepRow extends StatelessWidget {
  final IconData icon;
  final bool isPrimary;
  final String text;

  const _StepRow({
    required this.icon,
    required this.isPrimary,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? AppTheme.boksBlue : AppTheme.boksRed;
    final bgColor = isPrimary ? AppTheme.boksBlueLight : AppTheme.boksRedLight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 13,
                color: AppTheme.textMid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cvEnabled = false;
  bool _isDark = true;
  int _presetIndex = 0;
  int _talkSilenceMs = SettingsService.defaultTalkSilenceMs;
  bool _talkReadBack = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cv = await SettingsService.getCvEnabled();
    final dark = await SettingsService.getIsDarkMode();
    final preset = await SettingsService.getThemePreset();
    final silenceMs = await SettingsService.getTalkSilenceMs();
    final readBack = await SettingsService.getTalkReadBack();
    if (!mounted) return;
    setState(() {
      _cvEnabled = cv;
      _isDark = dark;
      _presetIndex = preset;
      _talkSilenceMs = silenceMs;
      _talkReadBack = readBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        children: [
          _sectionHeader('APPEARANCE'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.boksBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dark_mode_rounded,
                    color: AppTheme.boksBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toggle between dark and light theme',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 12,
                          color: AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDark,
                  activeThumbColor: AppTheme.boksBlue,
                  activeTrackColor: AppTheme.boksBlueLight,
                  onChanged: (v) async {
                    AppTheme.setMode(v);
                    await SettingsService.setIsDarkMode(v);
                    setState(() => _isDark = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('THEME'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: List.generate(AppTheme.presets.length, (i) {
              final preset = AppTheme.presets[i];
              final selected = _presetIndex == i;
              return GestureDetector(
                onTap: () async {
                  AppTheme.setPreset(i);
                  await SettingsService.setThemePreset(i);
                  setState(() => _presetIndex = i);
                },
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppTheme.boksBlue
                                : AppTheme.bubblePurple,
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Row(
                            children: [
                              Expanded(child: Container(color: preset.primary)),
                              Expanded(child: Container(color: preset.accent)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preset.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 11,
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
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _sectionHeader('COMPUTER VISION'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.boksBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.boksBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Computer Vision',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Identify items from photos using on-device AI',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 12,
                          color: AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _cvEnabled,
                  activeThumbColor: AppTheme.boksBlue,
                  activeTrackColor: AppTheme.boksBlueLight,
                  onChanged: (v) async {
                    if (v) {
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Experimental Feature',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          content: const Text(
                            'Computer vision is experimental. The current models are not very accurate — results are expected to improve over time.',
                            style: TextStyle(fontFamily: kFontFamily),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    }
                    await SettingsService.setCvEnabled(v);
                    setState(() => _cvEnabled = v);
                  },
                ),
              ],
            ),
          ),
          if (_cvEnabled) ...[
            const SizedBox(height: 20),
            _sectionHeader('HOW IT WORKS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
              ),
              child: const Column(
                children: [
                  _StepRow(
                    icon: Icons.camera_alt_rounded,
                    isPrimary: true,
                    text: 'Take a photo of your item',
                  ),
                  SizedBox(height: 12),
                  _StepRow(
                    icon: Icons.auto_awesome_rounded,
                    isPrimary: false,
                    text: 'On-device AI analyzes the image instantly',
                  ),
                  SizedBox(height: 12),
                  _StepRow(
                    icon: Icons.checklist_rounded,
                    isPrimary: true,
                    text: 'Pick from 5 guesses or type the name yourself',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _sectionHeader('BOKSTALK'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.boksBlueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.timer_rounded,
                        color: AppTheme.boksBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Silence Timeout',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '${(_talkSilenceMs / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.boksBlueBright,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _talkSilenceMs.toDouble(),
                  min: 500,
                  max: 5000,
                  divisions: 9,
                  activeColor: AppTheme.boksBlue,
                  inactiveColor: AppTheme.boksBlueLight,
                  onChanged: (v) => setState(() => _talkSilenceMs = v.round()),
                  onChangeEnd: (v) =>
                      SettingsService.setTalkSilenceMs(v.round()),
                ),
                Text(
                  'Stop listening after this long with no speech',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 12,
                    color: AppTheme.textMid,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.bubblePurple),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.boksRedLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.volume_up_rounded,
                        color: AppTheme.boksRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Read Back',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Speak the heard words aloud before adding',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 12,
                              color: AppTheme.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _talkReadBack,
                      activeThumbColor: AppTheme.boksRed,
                      activeTrackColor: AppTheme.boksRedLight,
                      onChanged: (v) async {
                        await SettingsService.setTalkReadBack(v);
                        setState(() => _talkReadBack = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.bubblePurple, width: 1),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppTheme.boksBlueBright,
        ),
      ),
    );
  }
}

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

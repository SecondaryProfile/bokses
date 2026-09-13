import 'package:flutter/material.dart';
import '../models/ai_provider.dart';
import '../services/ai_vision_settings_service.dart';
import '../services/secure_key_store.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class AiProviderScreen extends StatefulWidget {
  const AiProviderScreen({super.key});

  @override
  State<AiProviderScreen> createState() => _AiProviderScreenState();
}

class _AiProviderScreenState extends State<AiProviderScreen> {
  final Map<AiProvider, bool> _hasKey = {};
  final Map<AiProvider, TextEditingController> _controllers = {
    for (final def in kAiProviders) def.provider: TextEditingController(),
  };
  final Map<AiProvider, bool> _obscure = {
    for (final def in kAiProviders) def.provider: true,
  };
  AiProvider? _activeProvider;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final results = <AiProvider, bool>{};
    for (final def in kAiProviders) {
      results[def.provider] = await SecureKeyStore.hasKey(def.provider);
    }
    final active = await AiVisionSettingsService.activeProvider();
    if (mounted) {
      setState(() {
        _hasKey.addAll(results);
        _activeProvider = active;
      });
    }
  }

  Color _providerColor(AiProvider provider) {
    final t = kAiProviders.indexWhere((d) => d.provider == provider) /
        (kAiProviders.length - 1);
    return Color.lerp(AppTheme.boksBlue, AppTheme.boksRed, t)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Provider')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildPrivacyNote(),
          const SizedBox(height: 16),
          ...kAiProviders.map((def) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildProviderCard(def),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.boksBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.boksBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.boksBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your API key is encrypted and stored only in this browser — '
              'Bokses never sees it. Anyone using this browser profile can '
              'use the key, so avoid a shared machine. Photos are sent '
              'directly over an encrypted connection to your chosen provider '
              'only when you tap to identify an item, never in the background '
              'and never through a Bokses server.',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(AiProviderDef def) {
    final color = _providerColor(def.provider);
    final hasKey = _hasKey[def.provider] ?? false;
    final isActive = _activeProvider == def.provider;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  def.displayName,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const Spacer(),
                if (isActive) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFF27AE60)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, size: 12, color: Color(0xFF27AE60)),
                        SizedBox(width: 4),
                        Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF27AE60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.description,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 13,
                    color: AppTheme.textMid,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get a key at ${def.getKeyUrl}',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 14),
                if (hasKey) ...[
                  Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 16, color: Color(0xFF27AE60)),
                      const SizedBox(width: 6),
                      Text(
                        'Key saved',
                        style: const TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF27AE60),
                        ),
                      ),
                      const Spacer(),
                      if (!isActive)
                        TextButton(
                          onPressed: _saving ? null : () => _setActive(def.provider),
                          child: Text(
                            'Use This',
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: _saving ? null : () => _removeKey(def.provider),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: _controllers[def.provider],
                    obscureText: _obscure[def.provider] ?? true,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(fontFamily: kFontFamily, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: def.keyHint,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          (_obscure[def.provider] ?? true)
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                        ),
                        onPressed: () => setState(() {
                          _obscure[def.provider] = !(_obscure[def.provider] ?? true);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: color),
                      onPressed: _saving ? null : () => _saveKey(def.provider),
                      child: const Text('Save Key'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveKey(AiProvider provider) async {
    final key = _controllers[provider]!.text.trim();
    if (key.isEmpty) return;

    setState(() => _saving = true);
    await SecureKeyStore.saveKey(provider, key);
    final active = await AiVisionSettingsService.activeProvider();
    if (active == null) {
      await AiVisionSettingsService.setActiveProvider(provider);
    }
    _controllers[provider]!.clear();
    if (mounted) setState(() => _saving = false);
    await _reload();
  }

  Future<void> _setActive(AiProvider provider) async {
    await AiVisionSettingsService.setActiveProvider(provider);
    await _reload();
  }

  Future<void> _removeKey(AiProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: Text(
          'This key will be deleted from this browser.',
          style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await SecureKeyStore.deleteKey(provider);
    if (_activeProvider == provider) {
      await AiVisionSettingsService.setActiveProvider(null);
    }
    await _reload();
  }
}

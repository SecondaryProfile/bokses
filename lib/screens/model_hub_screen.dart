import 'package:flutter/material.dart';
import '../models/cv_model_def.dart';
import '../services/model_service.dart';
import '../services/vision_service.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class ModelHubScreen extends StatefulWidget {
  const ModelHubScreen({super.key});

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  final Map<CvModelTier, bool> _installed = {};
  CvModelTier? _activeTier;
  CvModelTier? _downloadingTier;
  double _downloadProgress = 0;
  bool _cancelDownload = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final results = <CvModelTier, bool>{};
    for (final def in kCvModels) {
      results[def.tier] = await ModelService.isInstalled(def.tier);
    }
    final active = await ModelService.activeTier();
    if (mounted) {
      setState(() {
        _installed.addAll(results);
        _activeTier = active;
      });
    }
  }

  Color _tierColor(CvModelTier tier) {
    final t = tier.index / (CvModelTier.values.length - 1);
    return Color.lerp(AppTheme.boksBlue, AppTheme.boksRed, t)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Hub')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: kCvModels.map((def) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTierCard(def),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTierCard(CvModelDef def) {
    final tierColor = _tierColor(def.tier);
    final isActive = _activeTier == def.tier;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tierColor, width: 2.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    def.tier.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  def.modelName,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.bubblePurple),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    def.isTflite ? 'TFLite' : 'ONNX',
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statChip(Icons.memory_rounded, def.paramCount, tierColor),
                    const SizedBox(width: 8),
                    _statChip(Icons.download_rounded, def.downloadSize, tierColor),
                    const SizedBox(width: 8),
                    _statChip(Icons.star_rounded, def.topFiveAccuracy, tierColor),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  def.description,
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 13,
                    color: AppTheme.textMid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: AppTheme.bubblePurple.withValues(alpha: 0.5),
          ),
          // Action area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _buildActionArea(def),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(CvModelDef def) {
    final tier = def.tier;
    final tierColor = _tierColor(tier);
    final isInstalledTier = _installed[tier] ?? false;
    final isActive = _activeTier == tier;
    final isDownloadingThis = _downloadingTier == tier;
    final isDownloadingOther =
        _downloadingTier != null && _downloadingTier != tier;

    if (isDownloadingThis) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  color: tierColor,
                  backgroundColor: tierColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => setState(() => _cancelDownload = true),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: kFontFamily,
                color: AppTheme.boksRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (isInstalledTier && isActive) {
      return Row(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: Color(0xFF27AE60)),
              const SizedBox(width: 6),
              Text(
                'Installed',
                style: const TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF27AE60),
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _removeModel(tier),
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
      );
    }

    if (isInstalledTier && !isActive) {
      return Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tierColor),
            onPressed: isDownloadingOther ? null : () => _setActive(tier),
            child: const Text('Use This Model'),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _removeModel(tier),
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
      );
    }

    // Not installed
    return Opacity(
      opacity: isDownloadingOther ? 0.4 : 1.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: tierColor),
        onPressed: isDownloadingOther ? null : () => _startDownload(tier),
        child: const Text('Download'),
      ),
    );
  }

  Future<void> _startDownload(CvModelTier tier) async {
    if (kXlModel.embeddingsUrl == null && tier == CvModelTier.xl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'XL embeddings URL not configured. See tools/generate_clip_embeddings.py.',
          ),
        ),
      );
      return;
    }

    if (_activeTier != null && _activeTier != tier) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace Current Model?'),
          content: Text(
            'This will remove the currently installed model and download a new one.',
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
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ModelService.delete(_activeTier!);
      VisionService.invalidate();
      await _reload();
    }

    setState(() {
      _downloadingTier = tier;
      _downloadProgress = 0;
      _cancelDownload = false;
    });

    try {
      await ModelService.download(
        tier,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
        isCancelled: () => _cancelDownload,
      );
      await _reload();
      if (mounted) {
        setState(() {
          _downloadingTier = null;
          _downloadProgress = 0;
        });
      }
    } catch (e) {
      final wasCancelled = _cancelDownload;
      await ModelService.delete(tier);
      if (mounted) {
        setState(() {
          _downloadingTier = null;
          _downloadProgress = 0;
          _cancelDownload = false;
        });
        await _reload();
        if (!wasCancelled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeModel(CvModelTier tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Model?'),
        content: Text(
          'The model files will be deleted from your device.',
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
    await ModelService.delete(tier);
    VisionService.invalidate();
    await _reload();
  }

  Future<void> _setActive(CvModelTier tier) async {
    // Not reachable under one-at-a-time model, but kept for completeness.
    await _reload();
  }
}

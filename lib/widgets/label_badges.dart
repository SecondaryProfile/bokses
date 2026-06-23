import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';

// ── Painters ────────────────────────────────────────────────────────────────────

class StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.13);
    const stripeW = 5.0;
    const gap = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += stripeW + gap) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeW, 0)
        ..lineTo(x + stripeW + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    const radius = 2.0;
    const spacing = 7.0;
    for (double x = 4; x < size.width; x += spacing) {
      for (double y = 3; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Badge widgets ────────────────────────────────────────────────────────────────

class FragileBadge extends StatelessWidget {
  const FragileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 22,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFCC00)),
          child: CustomPaint(
            painter: StripePainter(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  'FRAGILE',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BatteryBadge extends StatelessWidget {
  const BatteryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 22,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFFE53935)],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Center(
            child: Text(
              'BATTERY',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidBadge extends StatelessWidget {
  const LiquidBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 22,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF1565C0)),
          child: CustomPaint(
            painter: DotsPainter(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  'LIQUID',
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget itemLabelBadge(ItemLabel label) {
  late final Widget badge;
  switch (label) {
    case ItemLabel.fragile:
      badge = const FragileBadge();
    case ItemLabel.battery:
      badge = const BatteryBadge();
    case ItemLabel.liquid:
      badge = const LiquidBadge();
  }
  return IntrinsicWidth(child: badge);
}

// ── Compact row of badges ────────────────────────────────────────────────────────

class LabelBadgesRow extends StatelessWidget {
  final Set<ItemLabel> labels;
  const LabelBadgesRow({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final ordered = ItemLabel.values.where(labels.contains).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: ordered.map(itemLabelBadge).toList(),
    );
  }
}

// ── Label picker bottom sheet ────────────────────────────────────────────────────

class LabelPickerSheet extends StatefulWidget {
  final List<ItemLabel> initial;
  const LabelPickerSheet({super.key, required this.initial});

  @override
  State<LabelPickerSheet> createState() => _LabelPickerSheetState();
}

class _LabelPickerSheetState extends State<LabelPickerSheet> {
  late Set<ItemLabel> _selected;

  static const _displayNames = {
    ItemLabel.fragile: 'Fragile',
    ItemLabel.battery: 'Battery',
    ItemLabel.liquid: 'Liquid',
  };

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.bubblePurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Labels',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to toggle',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: 13,
              color: AppTheme.textMid,
            ),
          ),
          const SizedBox(height: 20),
          ...ItemLabel.values.map((label) {
            final selected = _selected.contains(label);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selected.remove(label);
                  } else {
                    _selected.add(label);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.boksBlueLight
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppTheme.boksBlue
                          : AppTheme.bubblePurple,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      itemLabelBadge(label),
                      const SizedBox(width: 12),
                      Text(
                        _displayNames[label]!,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected
                            ? AppTheme.boksBlueBright
                            : AppTheme.textMid,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected.toList()),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile-view label pills ────────────────────────────────────────────────────────
// Fills available width next to the item count.  Each pill renders its full
// pattern (stripes / gradient / dots) when wide enough, otherwise solid colour.

class LabelPillsRow extends StatelessWidget {
  final Set<ItemLabel> labels;
  const LabelPillsRow({super.key, required this.labels});

  static const double _pillH = 13;
  static const double _gap = 4;
  static const double _patternThreshold = 30;

  Widget _pill(ItemLabel label, double width) {
    final showPattern = width >= _patternThreshold;
    final radius = BorderRadius.circular(4);

    switch (label) {
      case ItemLabel.fragile:
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: width,
            height: _pillH,
            child: showPattern
                ? DecoratedBox(
                    decoration:
                        const BoxDecoration(color: Color(0xFFFFCC00)),
                    child: CustomPaint(painter: StripePainter()),
                  )
                : const ColoredBox(color: Color(0xFFFFCC00)),
          ),
        );
      case ItemLabel.battery:
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: width,
            height: _pillH,
            child: DecoratedBox(
              decoration: showPattern
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFFE53935)],
                      ),
                    )
                  : const BoxDecoration(color: Color(0xFFE53935)),
            ),
          ),
        );
      case ItemLabel.liquid:
        return ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: width,
            height: _pillH,
            child: showPattern
                ? DecoratedBox(
                    decoration:
                        const BoxDecoration(color: Color(0xFF1565C0)),
                    child: CustomPaint(painter: DotsPainter()),
                  )
                : const ColoredBox(color: Color(0xFF1565C0)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final ordered = ItemLabel.values.where(labels.contains).toList();
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxCount = ItemLabel.values.length;
        final totalGap = _gap * (maxCount - 1);
        final pillWidth =
            (constraints.maxWidth - totalGap) / maxCount;
        return Row(
          children: [
            for (int i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              _pill(ordered[i], pillWidth.clamp(0, constraints.maxWidth)),
            ],
          ],
        );
      },
    );
  }
}

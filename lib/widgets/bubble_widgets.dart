import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

/// Passthrough wrapper — no visual background decoration.
class BubbleBackground extends StatelessWidget {
  final Widget child;
  const BubbleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Flat dark card with subtle border, matching caybullz-style flat design.
class BoksCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const BoksCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.bubblePurple, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// Pill-shaped colored badge.
class BoksBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const BoksBadge(
      {super.key,
      required this.label,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontFamily,
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

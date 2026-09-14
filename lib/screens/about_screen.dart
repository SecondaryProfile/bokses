import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/bubble_widgets.dart';
import '../constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          children: [
            const SizedBox(height: 40),

            Text(
              'BOKSES',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: AppTheme.boksBlueBright,
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 8),

            BoksBadge(
              label: kAppVersion,
              color: AppTheme.boksBlueLight,
              textColor: AppTheme.boksBlueBright,
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 32),

            _InfoCard(
              icon: Icons.inventory_2_outlined,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'What is Bokses?',
              body:
                  'Bokses helps you keep track of what\'s inside your physical storage boxes. '
                  'Whether you\'re moving house, storing seasonal items, or just staying organized, '
                  'Bokses makes sure you always know exactly where everything is.',
            ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.camera_alt_rounded,
              iconColor: AppTheme.boksRed,
              iconBg: AppTheme.boksRedLight,
              title: 'Photos by Camera',
              body:
                  'Every item in a box can have an optional photo taken directly '
                  'with your camera — so you can see at a glance what\'s inside without '
                  'opening a single box. Press and hold a photo too to blow it up.',
            ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.import_export_rounded,
              iconColor: AppTheme.boksBlue,
              iconBg: AppTheme.boksBlueLight,
              title: 'Import & Export',
              body:
                  'Export all your boxes and items as a portable '
                  'JSON file to back up or transfer to another device. Import it back '
                  'just as easily.',
            ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.dns_rounded,
              iconColor: AppTheme.boksRed,
              iconBg: AppTheme.boksRedLight,
              title: 'Stored on Your Server',
              body:
                  'All your box and item data lives on your personal server — '
                  'not in someone else\'s cloud. No accounts, no subscription, no tracking.',
            ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 14),

            _InfoCard(
              icon: Icons.crop_square_rounded,
              iconColor: AppTheme.bubblePurple,
              iconBg: AppTheme.surface,
              title: 'Absolute Simplicity',
              body:
                  'Bokses does one thing: tells you what\'s in your boxes. '
                  'No tags, no categories, no folders, no sync settings. '
                  'If it doesn\'t help you find something faster, it\'s not here.',
            ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return BoksCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark)),
                const SizedBox(height: 6),
                Text(body,
                    style: TextStyle(
                        fontFamily: kFontFamily,
                        fontSize: 14,
                        color: AppTheme.textMid,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

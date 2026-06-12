import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/bubble_widgets.dart';

class VersionHistoryScreen extends StatelessWidget {
  const VersionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Version History')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        itemCount: kChangelog.length,
        itemBuilder: (_, i) {
          final entry = kChangelog[i];
          final isLatest = i == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BoksCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BoksBadge(
                        label: 'v${entry.version}',
                        color: isLatest ? AppTheme.boksBlueLight : AppTheme.surface,
                        textColor: isLatest ? AppTheme.boksBlueBright : AppTheme.textMid,
                      ),
                      if (isLatest) ...[
                        const SizedBox(width: 8),
                        BoksBadge(
                          label: 'Latest',
                          color: AppTheme.boksRedLight,
                          textColor: AppTheme.boksRedBright,
                        ),
                      ],
                      const Spacer(),
                      Text(
                        entry.date,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 12,
                          color: AppTheme.textMid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...entry.changes.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isLatest ? AppTheme.boksBlueBright : AppTheme.textMid,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontFamily: kFontFamily,
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 60 * i), duration: 250.ms).slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

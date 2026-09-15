import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/web_open.dart' if (dart.library.html) '../services/web_open_web.dart';
import '../theme/app_theme.dart';

const String _repoIssuesUrl = 'https://github.com/SecondaryProfile/bokses/issues/new';

/// Prompts for a bug title and steps to reproduce, then opens a prefilled
/// GitHub "new issue" page in a new tab — nothing is sent automatically.
/// The reporter reviews the prefilled title/body on GitHub's own page and
/// submits it themselves.
Future<void> showReportBugDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ReportBugDialog(),
  );
}

class _ReportBugDialog extends StatefulWidget {
  const _ReportBugDialog();

  @override
  State<_ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<_ReportBugDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _steps = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _steps.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final body = '## Steps to reproduce\n${_steps.text.trim()}\n\n'
        '## App info\n- Version: v$kAppVersion';

    final url = Uri.parse(_repoIssuesUrl).replace(queryParameters: {
      'title': _title.text.trim(),
      'body': body,
      'labels': 'bug',
    });

    openInNewTab(url.toString());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Report a Bug',
        style: TextStyle(fontFamily: kFontFamily, fontWeight: FontWeight.w800),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This opens a prefilled GitHub issue in a new tab — nothing '
              'is sent until you review it there and submit it yourself.',
              style: TextStyle(fontFamily: kFontFamily, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Bug title'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a short title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _steps,
              decoration: const InputDecoration(
                labelText: 'Steps to reproduce',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Describe what you did and what went wrong'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textMid)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.boksBlue),
          child: const Text('Open on GitHub', style: TextStyle(fontFamily: kFontFamily)),
        ),
      ],
    );
  }
}

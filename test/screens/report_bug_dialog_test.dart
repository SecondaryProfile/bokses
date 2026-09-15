import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bokses/screens/report_bug_dialog.dart';
import 'package:bokses/theme/app_theme.dart';

Future<void> pumpDialog(WidgetTester tester) async {
  AppTheme.setMode(true);
  AppTheme.setPreset(0);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: Builder(
      builder: (ctx) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showReportBugDialog(ctx),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a title and steps-to-reproduce field', (t) async {
    await pumpDialog(t);
    expect(find.text('Report a Bug'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Bug title'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Steps to reproduce'), findsOneWidget);
  });

  testWidgets('validates both fields before submitting', (t) async {
    await pumpDialog(t);
    await t.tap(find.text('Open on GitHub'));
    await t.pumpAndSettle();
    expect(find.text('Enter a short title'), findsOneWidget);
    expect(find.text('Describe what you did and what went wrong'), findsOneWidget);
    // Still open — nothing was submitted.
    expect(find.text('Report a Bug'), findsOneWidget);
  });

  testWidgets('submitting with both fields filled closes the dialog', (t) async {
    await pumpDialog(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Bug title'), 'Photos disappear');
    await t.enterText(find.widgetWithText(TextFormField, 'Steps to reproduce'),
        'Add a photo, then reload the page.');
    await t.tap(find.text('Open on GitHub'));
    await t.pumpAndSettle();
    expect(find.text('Report a Bug'), findsNothing);
  });

  testWidgets('cancel closes the dialog', (t) async {
    await pumpDialog(t);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Report a Bug'), findsNothing);
  });
}

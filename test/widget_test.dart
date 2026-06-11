import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bokses/main.dart';
import 'package:bokses/models/box.dart';
import 'package:bokses/models/item.dart';
import 'package:bokses/theme/app_theme.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _box1 = Box(
  id: 'box-1',
  name: 'Kitchen Stuff',
  description: 'Plates and cutlery',
  createdAt: DateTime(2024, 1, 1),
);
final _box2 = Box(
  id: 'box-2',
  name: 'Books',
  createdAt: DateTime(2024, 1, 2),
);
final _item1 = Item(
  id: 'item-1',
  name: 'Red Plate',
  boxId: 'box-1',
  createdAt: DateTime(2024, 1, 1),
);
final _item2 = Item(
  id: 'item-2',
  name: 'Fork',
  boxId: 'box-1',
  createdAt: DateTime(2024, 1, 2),
);

// ── Helpers ───────────────────────────────────────────────────────────────────

String _encodeBoxes(List<Box> boxes) =>
    jsonEncode(boxes.map((b) => b.toMap()).toList());

String _encodeItems(List<Item> items) =>
    jsonEncode(items.map((i) => i.toMap()).toList());

Future<void> pumpApp(
  WidgetTester tester, {
  List<Box> boxes = const [],
  List<Item> items = const [],
}) async {
  AppTheme.setMode(true);
  AppTheme.setPreset(0);

  final mock = <String, Object>{};
  if (boxes.isNotEmpty) mock['bokses_boxes'] = _encodeBoxes(boxes);
  if (items.isNotEmpty) mock['bokses_items'] = _encodeItems(items);
  SharedPreferences.setMockInitialValues(mock);

  await tester.pumpWidget(const BoksesApp());
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Prevent GoogleFonts from making network requests during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Empty state ────────────────────────────────────────────────────────────

  group('HomeScreen — empty state', () {
    testWidgets('shows wordmark and tagline', (tester) async {
      await pumpApp(tester);
      expect(find.text('bokses'), findsOneWidget);
      expect(find.text('your storage, organized'), findsOneWidget);
    });

    testWidgets('stat chips show 0 boxes and 0 items', (tester) async {
      await pumpApp(tester);
      expect(find.text('0 boxes'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
    });

    testWidgets('shows empty state message', (tester) async {
      await pumpApp(tester);
      expect(find.text('No boxes yet!'), findsOneWidget);
    });

    testWidgets('shows New Box FAB', (tester) async {
      await pumpApp(tester);
      expect(find.text('New Box'), findsOneWidget);
    });
  });

  // ── Box grid ───────────────────────────────────────────────────────────────

  group('HomeScreen — with boxes', () {
    testWidgets('shows box names in grid', (tester) async {
      await pumpApp(tester, boxes: [_box1, _box2]);
      expect(find.text('Kitchen Stuff'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
    });

    testWidgets('stat chip shows correct box count', (tester) async {
      await pumpApp(tester, boxes: [_box1, _box2]);
      expect(find.text('2 boxes'), findsOneWidget);
    });

    testWidgets('stat chip shows correct item count', (tester) async {
      await pumpApp(tester, boxes: [_box1], items: [_item1, _item2]);
      expect(find.text('2 items'), findsAtLeastNWidgets(1));
    });

    testWidgets('singular: 1 box', (tester) async {
      await pumpApp(tester, boxes: [_box1]);
      expect(find.text('1 box'), findsOneWidget);
    });

    testWidgets('singular: 1 item on card', (tester) async {
      await pumpApp(tester, boxes: [_box1], items: [_item1]);
      expect(find.text('1 item'), findsAtLeastNWidgets(1));
    });

    testWidgets('empty state hidden when boxes exist', (tester) async {
      await pumpApp(tester, boxes: [_box1]);
      expect(find.text('No boxes yet!'), findsNothing);
    });
  });

  // ── Inline search ──────────────────────────────────────────────────────────

  group('HomeScreen — inline search', () {
    testWidgets('search icon shows text field and hides wordmark', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('your storage, organized'), findsNothing);
    });

    testWidgets('back arrow restores header', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('bokses'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('FAB hidden in search mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.text('New Box'), findsNothing);
    });

    testWidgets('typing < 3 chars shows prompt', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();
      expect(find.text('Type at least 3 characters'), findsOneWidget);
    });

    testWidgets('no matching results shows empty message', (tester) async {
      await pumpApp(tester, boxes: [_box1], items: [_item1]);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('matching query shows result tile', (tester) async {
      await pumpApp(tester, boxes: [_box1], items: [_item1]);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Plate');
      await tester.pumpAndSettle();
      expect(find.text('Red Plate', findRichText: true), findsOneWidget);
    });

    testWidgets('clear button appears when text entered', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });
  });

  // ── Add box dialog ─────────────────────────────────────────────────────────

  group('HomeScreen — add box dialog', () {
    testWidgets('FAB opens New Box bottom sheet', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New Box'));
      await tester.pumpAndSettle();
      expect(find.text('Create Box'), findsOneWidget);
    });

    testWidgets('empty name shows validation error', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New Box'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Box'));
      await tester.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });

    testWidgets('duplicate name shows validation error', (tester) async {
      await pumpApp(tester, boxes: [_box1]);
      await tester.tap(find.text('New Box'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Kitchen Stuff');
      await tester.tap(find.text('Create Box'));
      await tester.pumpAndSettle();
      expect(find.text('A box with this name already exists'), findsOneWidget);
    });
  });
}

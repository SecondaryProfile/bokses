import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bokses/main.dart';
import 'package:bokses/models/box.dart';
import 'package:bokses/models/item.dart';
import 'package:bokses/screens/box_detail_screen.dart';
import 'package:bokses/services/database_service.dart';
import 'package:bokses/services/import_export_service.dart';
import 'package:bokses/theme/app_theme.dart';

import 'helpers/fake_database_service.dart';

// ── Fixtures (factories so each test gets a fresh, unshared instance) ─────────

Box box1() => Box(
      id: 'box-1',
      name: 'Kitchen Stuff',
      description: 'Plates and cutlery',
      createdAt: DateTime(2024, 1, 1),
    );
Box box2() => Box(
      id: 'box-2',
      name: 'Books',
      createdAt: DateTime(2024, 1, 2),
    );
Item item1() => Item(
      id: 'item-1',
      name: 'Red Plate',
      boxId: 'box-1',
      createdAt: DateTime(2024, 1, 1),
    );
Item item2() => Item(
      id: 'item-2',
      name: 'Fork',
      boxId: 'box-1',
      createdAt: DateTime(2024, 1, 2),
    );

// ── Helpers ───────────────────────────────────────────────────────────────────

late FakeDatabaseService _fakeDb;

Future<void> pumpApp(
  WidgetTester tester, {
  List<Box> boxes = const [],
  List<Item> items = const [],
}) async {
  _fakeDb = FakeDatabaseService();
  for (final b in boxes) { await _fakeDb.insertBox(b); }
  for (final i in items) { await _fakeDb.insertItem(i); }
  DatabaseService.instance = _fakeDb;
  AppTheme.setMode(true);
  AppTheme.setPreset(0);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const BoksesApp());
  await tester.pumpAndSettle();
}

Future<void> pumpBoxDetail(
  WidgetTester tester,
  Box box, {
  List<Item> items = const [],
}) async {
  _fakeDb = FakeDatabaseService();
  await _fakeDb.insertBox(box);
  for (final i in items) { await _fakeDb.insertItem(i); }
  DatabaseService.instance = _fakeDb;
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: BoxDetailScreen(box: box),
  ));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ══════════════════════════════════════════════════════════════════════════
  // UNIT — Models
  // ══════════════════════════════════════════════════════════════════════════

  group('Box model', () {
    test('round-trips through toMap / fromMap', () {
      final box = Box(
          id: 'abc', name: 'Test', description: 'desc', createdAt: DateTime(2024, 6, 1));
      final copy = Box.fromMap(box.toMap());
      expect(copy.id, box.id);
      expect(copy.name, box.name);
      expect(copy.description, box.description);
      expect(copy.createdAt, box.createdAt);
    });

    test('null description survives round-trip', () {
      final box = Box(id: 'x', name: 'X', createdAt: DateTime(2024, 1, 1));
      expect(Box.fromMap(box.toMap()).description, isNull);
    });

    test('toExportMap contains required fields', () {
      final box = Box(id: 'e', name: 'Export', createdAt: DateTime(2024, 1, 1));
      final m = box.toExportMap();
      expect(m['id'], 'e');
      expect(m['name'], 'Export');
      expect(m.containsKey('createdAt'), isTrue);
    });
  });

  group('Item model', () {
    test('round-trips through toMap / fromMap', () {
      final item = Item(
          id: 'i1', name: 'Wrench', photoPath: 'data:image/jpeg;base64,abc',
          boxId: 'b1', createdAt: DateTime(2024, 3, 15));
      final copy = Item.fromMap(item.toMap());
      expect(copy.id, item.id);
      expect(copy.name, item.name);
      expect(copy.photoPath, item.photoPath);
      expect(copy.boxId, item.boxId);
    });

    test('null photoPath survives round-trip', () {
      final item = Item(id: 'i', name: 'X', boxId: 'b', createdAt: DateTime(2024, 1, 1));
      expect(Item.fromMap(item.toMap()).photoPath, isNull);
    });

    test('toExportMap omits photoPath', () {
      final item = Item(
          id: 'i', name: 'X', photoPath: '/some/path',
          boxId: 'b', createdAt: DateTime(2024, 1, 1));
      expect(item.toExportMap().containsKey('photoPath'), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // UNIT — FakeDatabaseService
  // ══════════════════════════════════════════════════════════════════════════

  group('FakeDatabaseService — boxes', () {
    late FakeDatabaseService db;
    setUp(() => db = FakeDatabaseService());

    test('insertBox adds a box', () async {
      await db.insertBox(box1());
      expect((await db.getBoxes()).length, 1);
    });

    test('getBoxes returns sorted by createdAt', () async {
      await db.insertBox(box2());
      await db.insertBox(box1());
      expect((await db.getBoxes()).first.id, 'box-1');
    });

    test('insertBox upserts on same id', () async {
      await db.insertBox(box1());
      await db.insertBox(Box(id: 'box-1', name: 'Updated', createdAt: DateTime(2024, 1, 1)));
      final boxes = await db.getBoxes();
      expect(boxes.length, 1);
      expect(boxes.first.name, 'Updated');
    });

    test('updateBox changes name', () async {
      final b = box1();
      await db.insertBox(b);
      b.name = 'Renamed';
      await db.updateBox(b);
      expect((await db.getBoxes()).first.name, 'Renamed');
    });

    test('deleteBox removes box', () async {
      await db.insertBox(box1());
      await db.deleteBox('box-1');
      expect((await db.getBoxes()), isEmpty);
    });

    test('deleteBox cascades items', () async {
      await db.insertBox(box1());
      await db.insertItem(item1());
      await db.deleteBox('box-1');
      expect((await db.getAllItems()), isEmpty);
    });
  });

  group('FakeDatabaseService — items', () {
    late FakeDatabaseService db;
    setUp(() async {
      db = FakeDatabaseService();
      await db.insertBox(box1());
    });

    test('insertItem adds an item', () async {
      await db.insertItem(item1());
      expect((await db.getItemsForBox('box-1')).length, 1);
    });

    test('getItemsForBox filters by box', () async {
      await db.insertBox(box2());
      await db.insertItem(item1());
      await db.insertItem(
          Item(id: 'other', name: 'X', boxId: 'box-2', createdAt: DateTime.now()));
      expect((await db.getItemsForBox('box-1')).length, 1);
    });

    test('getAllItems returns all', () async {
      await db.insertItem(item1());
      await db.insertItem(item2());
      expect((await db.getAllItems()).length, 2);
    });

    test('updateItem saves changes', () async {
      final i = item1();
      await db.insertItem(i);
      i.name = 'Blue Plate';
      await db.updateItem(i);
      expect((await db.getItemsForBox('box-1')).first.name, 'Blue Plate');
    });

    test('deleteItem removes item', () async {
      await db.insertItem(item1());
      await db.deleteItem('item-1');
      expect((await db.getAllItems()), isEmpty);
    });

    test('getItemCount returns correct count', () async {
      await db.insertItem(item1());
      await db.insertItem(item2());
      expect(await db.getItemCount('box-1'), 2);
    });

    test('clearAll removes everything', () async {
      await db.insertItem(item1());
      await db.clearAll();
      expect((await db.getAllItems()), isEmpty);
      expect((await db.getBoxes()), isEmpty);
    });
  });

  group('FakeDatabaseService — search', () {
    late FakeDatabaseService db;
    setUp(() async {
      db = FakeDatabaseService();
      await db.insertBox(box1());
      await db.insertItem(item1()); // Red Plate
      await db.insertItem(item2()); // Fork
    });

    test('query < 3 chars returns empty', () async {
      expect(await db.searchItems('Re'), isEmpty);
    });

    test('matching query returns results', () async {
      final r = await db.searchItems('Plate');
      expect(r.length, 1);
      expect(r.first.item.name, 'Red Plate');
    });

    test('case-insensitive match', () async {
      expect(await db.searchItems('plate'), isNotEmpty);
    });

    test('no match returns empty', () async {
      expect(await db.searchItems('xyz'), isEmpty);
    });

    test('results sorted alphabetically', () async {
      await db.insertItem(
          Item(id: 'i3', name: 'Soup Bowl', boxId: 'box-1', createdAt: DateTime.now()));
      final names = (await db.searchItems('o')).map((e) => e.item.name).toList();
      expect(names, orderedEquals(names.toList()..sort()));
    });

    test('result includes parent box', () async {
      final r = await db.searchItems('Plate');
      expect(r.first.box.id, 'box-1');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // UNIT — Import / Export
  // ══════════════════════════════════════════════════════════════════════════

  group('buildExportPayload', () {
    setUp(() {
      _fakeDb = FakeDatabaseService();
      DatabaseService.instance = _fakeDb;
    });

    test('empty database produces valid structure', () async {
      final p = await ImportExportService.buildExportPayload();
      expect(p['app'], 'Bokses');
      expect(p['version'], '1.1');
      expect(p['boxes'], isEmpty);
      expect(p['items'], isEmpty);
      expect(p.containsKey('exportedAt'), isTrue);
    });

    test('boxes and items appear in payload', () async {
      await _fakeDb.insertBox(box1());
      await _fakeDb.insertItem(item1());
      final p = await ImportExportService.buildExportPayload();
      expect((p['boxes'] as List).length, 1);
      expect((p['items'] as List).length, 1);
    });

    test('payload serialises to valid JSON', () async {
      await _fakeDb.insertBox(box1());
      final p = await ImportExportService.buildExportPayload();
      expect(() => jsonEncode(p), returnsNormally);
    });
  });

  group('processImportJson', () {
    setUp(() {
      _fakeDb = FakeDatabaseService();
      DatabaseService.instance = _fakeDb;
    });

    test('rejects HTML input', () async {
      expect(
        await ImportExportService.processImportJson('<!DOCTYPE html>'),
        contains('Invalid file'),
      );
    });

    test('rejects wrong app field', () async {
      expect(
        await ImportExportService.processImportJson(
            jsonEncode({'app': 'Other', 'boxes': [], 'items': []})),
        contains('Invalid Bokses'),
      );
    });

    test('imports boxes and items', () async {
      final payload = jsonEncode({
        'app': 'Bokses',
        'version': '1.1',
        'exportedAt': DateTime.now().toIso8601String(),
        'boxes': [box1().toExportMap()],
        'items': [item1().toExportMap()],
      });
      final msg = await ImportExportService.processImportJson(payload);
      expect(msg, contains('1 box'));
      expect(msg, contains('1 item'));
      expect(_fakeDb.boxes.length, 1);
      expect(_fakeDb.items.length, 1);
    });

    test('handles empty arrays', () async {
      final msg = await ImportExportService.processImportJson(
          jsonEncode({'app': 'Bokses', 'boxes': [], 'items': []}));
      expect(msg, contains('0 box'));
    });

    test('round-trip: export → import restores data', () async {
      await _fakeDb.insertBox(box1());
      await _fakeDb.insertItem(item1());
      final payload = await ImportExportService.buildExportPayload();

      final fresh = FakeDatabaseService();
      DatabaseService.instance = fresh;
      await ImportExportService.processImportJson(jsonEncode(payload));

      expect(fresh.boxes.length, 1);
      expect(fresh.boxes.first.name, 'Kitchen Stuff');
      expect(fresh.items.first.name, 'Red Plate');
    });

    test('import with photoData restores data: URI on item', () async {
      final payload = jsonEncode({
        'app': 'Bokses',
        'boxes': [box1().toExportMap()],
        'items': [
          {...item1().toExportMap(), 'photoData': 'abc123'},
        ],
      });
      await ImportExportService.processImportJson(payload);
      expect(_fakeDb.items.first.photoPath, contains('base64,abc123'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen empty state
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — empty state', () {
    testWidgets('shows Bokses wordmark', (t) async {
      await pumpApp(t);
      expect(find.text('Bokses'), findsWidgets);
    });

    testWidgets('shows 0 boxes and 0 items chips', (t) async {
      await pumpApp(t);
      expect(find.text('0 boxes'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
    });

    testWidgets('shows empty state message', (t) async {
      await pumpApp(t);
      expect(find.text('No boxes yet!'), findsOneWidget);
    });

    testWidgets('shows New Box FAB', (t) async {
      await pumpApp(t);
      expect(find.text('New Box'), findsOneWidget);
    });

    testWidgets('version footer visible', (t) async {
      await pumpApp(t);
      expect(find.textContaining('v0.0'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen box grid
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — box grid', () {
    testWidgets('shows box names', (t) async {
      await pumpApp(t, boxes: [box1(), box2()]);
      expect(find.text('Kitchen Stuff'), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
    });

    testWidgets('correct box count chip', (t) async {
      await pumpApp(t, boxes: [box1(), box2()]);
      expect(find.text('2 boxes'), findsOneWidget);
    });

    testWidgets('singular: 1 box', (t) async {
      await pumpApp(t, boxes: [box1()]);
      expect(find.text('1 box'), findsOneWidget);
    });

    testWidgets('item count chip', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1(), item2()]);
      expect(find.text('2 items'), findsAtLeastNWidgets(1));
    });

    testWidgets('singular: 1 item', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1()]);
      expect(find.text('1 item'), findsAtLeastNWidgets(1));
    });

    testWidgets('box description shows on card', (t) async {
      await pumpApp(t, boxes: [box1()]);
      expect(find.text('Plates and cutlery'), findsOneWidget);
    });

    testWidgets('empty state hidden when boxes exist', (t) async {
      await pumpApp(t, boxes: [box1()]);
      expect(find.text('No boxes yet!'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen add box
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — add box', () {
    testWidgets('FAB opens bottom sheet', (t) async {
      await pumpApp(t);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      expect(find.text('Create Box'), findsOneWidget);
    });

    testWidgets('empty name → validation error', (t) async {
      await pumpApp(t);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });

    testWidgets('whitespace-only name → validation error', (t) async {
      await pumpApp(t);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '   ');
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });

    testWidgets('duplicate name → validation error', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Kitchen Stuff');
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(find.text('A box with this name already exists'), findsOneWidget);
    });

    testWidgets('duplicate name is case-insensitive', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'kitchen stuff');
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(find.text('A box with this name already exists'), findsOneWidget);
    });

    testWidgets('valid name creates box', (t) async {
      await pumpApp(t);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'New Test Box');
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(find.text('New Test Box'), findsOneWidget);
      expect(_fakeDb.boxes.any((b) => b.name == 'New Test Box'), isTrue);
    });

    testWidgets('optional description is saved', (t) async {
      await pumpApp(t);
      await t.tap(find.text('New Box'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), 'My Box');
      await t.enterText(find.byType(TextFormField).at(1), 'My desc');
      await t.tap(find.text('Create Box'));
      await t.pumpAndSettle();
      expect(_fakeDb.boxes.first.description, 'My desc');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen edit box
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — edit box', () {
    testWidgets('edit opens sheet with existing name', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      expect(find.text('Edit Box'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Kitchen Stuff'), findsOneWidget);
    });

    testWidgets('renaming saves new name', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Renamed Box');
      await t.tap(find.text('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('Renamed Box'), findsOneWidget);
    });

    testWidgets('empty name during edit → validation error', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '');
      await t.tap(find.text('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });

    testWidgets('duplicate name during edit → validation error', (t) async {
      await pumpApp(t, boxes: [box1(), box2()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Books');
      await t.tap(find.text('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('A box with this name already exists'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen delete box
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — delete box', () {
    testWidgets('delete opens confirmation dialog', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling keeps box', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Kitchen Stuff'), findsOneWidget);
    });

    testWidgets('confirming removes box', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text('Kitchen Stuff'), findsNothing);
      expect(_fakeDb.boxes, isEmpty);
    });

    testWidgets('deleting box also removes its items', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1()]);
      await t.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await t.pumpAndSettle();
      expect(_fakeDb.items, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — HomeScreen search
  // ══════════════════════════════════════════════════════════════════════════

  group('HomeScreen — search', () {
    testWidgets('search icon opens text field', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('FAB hidden in search mode', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      expect(find.text('New Box'), findsNothing);
    });

    testWidgets('back arrow exits search', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.arrow_back_rounded));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('typing < 3 chars shows prompt', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'ab');
      await t.pumpAndSettle();
      expect(find.text('Type at least 3 characters'), findsOneWidget);
    });

    testWidgets('no match shows empty message', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1()]);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'xyz');
      await t.pumpAndSettle();
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('matching query shows result tile', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1()]);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Plate');
      await t.pumpAndSettle();
      expect(find.text('Red Plate', findRichText: true), findsOneWidget);
    });

    testWidgets('result tile shows parent box name', (t) async {
      await pumpApp(t, boxes: [box1()], items: [item1()]);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Plate');
      await t.pumpAndSettle();
      expect(find.text('Kitchen Stuff'), findsAtLeastNWidgets(1));
    });

    testWidgets('clear button appears when text entered', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'abc');
      await t.pump();
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('clear button clears field and resets state', (t) async {
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.search_rounded));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'abc');
      await t.pump();
      await t.tap(find.byIcon(Icons.clear_rounded));
      await t.pumpAndSettle();
      expect(find.text('Type at least 3 characters'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — Navigation
  // ══════════════════════════════════════════════════════════════════════════

  group('Navigation', () {
    testWidgets('tapping box card opens BoxDetailScreen', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.text('Kitchen Stuff'));
      await t.pumpAndSettle();
      expect(find.text('Box is empty!'), findsOneWidget);
    });

    testWidgets('back from BoxDetail returns to HomeScreen', (t) async {
      await pumpApp(t, boxes: [box1()]);
      await t.tap(find.text('Kitchen Stuff'));
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Kitchen Stuff'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — BoxDetailScreen empty state
  // ══════════════════════════════════════════════════════════════════════════

  group('BoxDetailScreen — empty state', () {
    testWidgets('shows box name in app bar', (t) async {
      await pumpBoxDetail(t, box1());
      expect(find.text('Kitchen Stuff'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows empty box message', (t) async {
      await pumpBoxDetail(t, box1());
      expect(find.text('Box is empty!'), findsOneWidget);
    });

    testWidgets('shows Add Item FAB', (t) async {
      await pumpBoxDetail(t, box1());
      expect(find.text('Add Item'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — BoxDetailScreen item list
  // ══════════════════════════════════════════════════════════════════════════

  group('BoxDetailScreen — item list', () {
    testWidgets('shows item names', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1(), item2()]);
      expect(find.text('Red Plate'), findsOneWidget);
      expect(find.text('Fork'), findsOneWidget);
    });

    testWidgets('shows no-photo label', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      expect(find.text('No photo'), findsOneWidget);
    });

    testWidgets('empty state hidden when items exist', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      expect(find.text('Box is empty!'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — BoxDetailScreen add item
  // ══════════════════════════════════════════════════════════════════════════

  group('BoxDetailScreen — add item', () {
    testWidgets('Add Item FAB opens sheet', (t) async {
      await pumpBoxDetail(t, box1());
      await t.tap(find.text('Add Item'));
      await t.pumpAndSettle();
      expect(find.text('Add Item', skipOffstage: false), findsAtLeastNWidgets(1));
    });

    testWidgets('empty name → validation error', (t) async {
      await pumpBoxDetail(t, box1());
      await t.tap(find.text('Add Item'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await t.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });

    testWidgets('valid name creates item', (t) async {
      await pumpBoxDetail(t, box1());
      await t.tap(find.text('Add Item'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Hammer');
      await t.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await t.pumpAndSettle();
      expect(find.text('Hammer'), findsOneWidget);
      expect(_fakeDb.items.any((i) => i.name == 'Hammer'), isTrue);
    });

    testWidgets('created item belongs to correct box', (t) async {
      await pumpBoxDetail(t, box1());
      await t.tap(find.text('Add Item'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Wrench');
      await t.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
      await t.pumpAndSettle();
      expect(_fakeDb.items.first.boxId, 'box-1');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — BoxDetailScreen edit item
  // ══════════════════════════════════════════════════════════════════════════

  group('BoxDetailScreen — edit item', () {
    testWidgets('edit opens sheet with existing name', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Red Plate'), findsOneWidget);
    });

    testWidgets('renaming item saves new name', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Blue Plate');
      await t.tap(find.text('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('Blue Plate'), findsOneWidget);
      expect(find.text('Red Plate'), findsNothing);
    });

    testWidgets('empty name during edit → validation error', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '');
      await t.tap(find.text('Save Changes'));
      await t.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGET — BoxDetailScreen delete item
  // ══════════════════════════════════════════════════════════════════════════

  group('BoxDetailScreen — delete item', () {
    testWidgets('delete opens confirmation dialog', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling keeps item', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Red Plate'), findsOneWidget);
    });

    testWidgets('confirming removes item', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text('Red Plate'), findsNothing);
      expect(_fakeDb.items, isEmpty);
    });

    testWidgets('deleting last item shows empty state', (t) async {
      await pumpBoxDetail(t, box1(), items: [item1()]);
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await t.pumpAndSettle();
      expect(find.text('Box is empty!'), findsOneWidget);
    });
  });
}

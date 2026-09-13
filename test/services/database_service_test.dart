// Tests for the real DatabaseService — the SharedPreferences-backed store the
// app ships with. The widget tests use FakeDatabaseService, so without this
// file the persistence layer itself would be untested.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bokses/models/box.dart';
import 'package:bokses/models/item.dart';
import 'package:bokses/services/database_service.dart';

Box _box(String id, {String? name, int day = 1}) => Box(
      id: id,
      name: name ?? 'Box $id',
      createdAt: DateTime(2024, 1, day),
    );

Item _item(String id, String boxId,
        {String? name, int day = 1, List<ItemLabel>? labels}) =>
    Item(
      id: id,
      name: name ?? 'Item $id',
      boxId: boxId,
      createdAt: DateTime(2024, 1, day),
      labels: labels,
    );

void main() {
  late DatabaseService db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService.forTesting();
  });

  group('DatabaseService — persistence', () {
    test('empty storage reads as no boxes and no items', () async {
      expect(await db.getBoxes(), isEmpty);
      expect(await db.getAllItems(), isEmpty);
    });

    test('data written by one instance is read by another', () async {
      await db.insertBox(_box('b1', name: 'Garage'));
      await db.insertItem(_item('i1', 'b1', name: 'Drill'));

      final reopened = DatabaseService.forTesting();
      expect((await reopened.getBoxes()).single.name, 'Garage');
      expect((await reopened.getAllItems()).single.name, 'Drill');
    });

    test('stores JSON under the local_boxes / local_items keys', () async {
      await db.insertBox(_box('b1'));
      await db.insertItem(_item('i1', 'b1'));

      final prefs = await SharedPreferences.getInstance();
      final boxes = json.decode(prefs.getString('local_boxes')!) as List;
      final items = json.decode(prefs.getString('local_items')!) as List;
      expect(boxes.single['id'], 'b1');
      expect(items.single['boxId'], 'b1');
    });

    test('reads data already present in storage', () async {
      SharedPreferences.setMockInitialValues({
        'local_boxes': json.encode([_box('b9', name: 'Attic').toMap()]),
        'local_items': json.encode([_item('i9', 'b9', name: 'Lamp').toMap()]),
      });
      final fresh = DatabaseService.forTesting();
      expect((await fresh.getBoxes()).single.name, 'Attic');
      expect((await fresh.getItemsForBox('b9')).single.name, 'Lamp');
    });

    test('item photo, webPhoto flag and labels survive storage', () async {
      await db.insertBox(_box('b1'));
      await db.insertItem(Item(
        id: 'i1',
        name: 'Vase',
        boxId: 'b1',
        createdAt: DateTime(2024, 1, 1),
        photoPath: 'https://example.com/vase.jpg',
        webPhoto: true,
        labels: [ItemLabel.fragile, ItemLabel.liquid],
      ));

      final item = (await DatabaseService.forTesting().getAllItems()).single;
      expect(item.photoPath, 'https://example.com/vase.jpg');
      expect(item.webPhoto, isTrue);
      expect(item.labels, [ItemLabel.fragile, ItemLabel.liquid]);
    });
  });

  group('DatabaseService — boxes', () {
    test('getBoxes sorts oldest first regardless of insert order', () async {
      await db.insertBox(_box('late', day: 20));
      await db.insertBox(_box('early', day: 2));
      await db.insertBox(_box('mid', day: 10));
      expect((await db.getBoxes()).map((b) => b.id), ['early', 'mid', 'late']);
    });

    test('insertBox with an existing id replaces it', () async {
      await db.insertBox(_box('b1', name: 'Old'));
      await db.insertBox(_box('b1', name: 'New'));
      final boxes = await db.getBoxes();
      expect(boxes, hasLength(1));
      expect(boxes.single.name, 'New');
    });

    test('updateBox saves the change', () async {
      await db.insertBox(_box('b1', name: 'Old'));
      await db.updateBox(_box('b1', name: 'Renamed'));
      expect((await db.getBoxes()).single.name, 'Renamed');
    });

    test('deleteBox removes the box and only its items', () async {
      await db.insertBox(_box('b1'));
      await db.insertBox(_box('b2'));
      await db.insertItem(_item('i1', 'b1'));
      await db.insertItem(_item('i2', 'b2'));

      await db.deleteBox('b1');

      expect((await db.getBoxes()).map((b) => b.id), ['b2']);
      expect((await db.getAllItems()).map((i) => i.id), ['i2']);
    });

    test('deleteBox with an unknown id changes nothing', () async {
      await db.insertBox(_box('b1'));
      await db.deleteBox('nope');
      expect(await db.getBoxes(), hasLength(1));
    });
  });

  group('DatabaseService — items', () {
    test('getItemsForBox filters by box and sorts oldest first', () async {
      await db.insertItem(_item('i3', 'b1', day: 3));
      await db.insertItem(_item('x', 'b2', day: 1));
      await db.insertItem(_item('i1', 'b1', day: 1));
      expect((await db.getItemsForBox('b1')).map((i) => i.id), ['i1', 'i3']);
    });

    test('insertItem with an existing id replaces it', () async {
      await db.insertItem(_item('i1', 'b1', name: 'Old'));
      await db.insertItem(_item('i1', 'b1', name: 'New'));
      final items = await db.getAllItems();
      expect(items, hasLength(1));
      expect(items.single.name, 'New');
    });

    test('updateItem can move an item to another box', () async {
      await db.insertItem(_item('i1', 'b1'));
      await db.updateItem(_item('i1', 'b2'));
      expect(await db.getItemsForBox('b1'), isEmpty);
      expect((await db.getItemsForBox('b2')).single.id, 'i1');
    });

    test('deleteItem removes only that item', () async {
      await db.insertItem(_item('i1', 'b1'));
      await db.insertItem(_item('i2', 'b1'));
      await db.deleteItem('i1');
      expect((await db.getAllItems()).map((i) => i.id), ['i2']);
    });

    test('getItemCount counts per box', () async {
      await db.insertItem(_item('i1', 'b1'));
      await db.insertItem(_item('i2', 'b1'));
      await db.insertItem(_item('i3', 'b2'));
      expect(await db.getItemCount('b1'), 2);
      expect(await db.getItemCount('b2'), 1);
      expect(await db.getItemCount('empty'), 0);
    });

    test('clearAll removes boxes, items and their storage keys', () async {
      await db.insertBox(_box('b1'));
      await db.insertItem(_item('i1', 'b1'));
      await db.clearAll();

      expect(await db.getBoxes(), isEmpty);
      expect(await db.getAllItems(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('local_boxes'), isFalse);
      expect(prefs.containsKey('local_items'), isFalse);
    });
  });

  group('DatabaseService — search', () {
    setUp(() async {
      await db.insertBox(_box('b1', name: 'Garage'));
      await db.insertBox(_box('b2', name: 'Kitchen'));
      await db.insertItem(_item('i1', 'b1', name: 'Power Drill'));
      await db.insertItem(_item('i2', 'b2', name: 'drill bits'));
      await db.insertItem(_item('i3', 'b2', name: 'Whisk'));
    });

    test('queries shorter than 3 characters return nothing', () async {
      expect(await db.searchItems('dr'), isEmpty);
    });

    test('matches case-insensitively and sorts by item name', () async {
      final results = await db.searchItems('DRILL');
      expect(results.map((r) => r.item.name), ['drill bits', 'Power Drill']);
    });

    test('each result carries its parent box', () async {
      final results = await db.searchItems('whisk');
      expect(results.single.box.name, 'Kitchen');
    });

    test('items whose box no longer exists are skipped', () async {
      await db.insertItem(_item('orphan', 'gone', name: 'Orphan drill'));
      final results = await db.searchItems('drill');
      expect(results.map((r) => r.item.id), isNot(contains('orphan')));
    });
  });

  group('DatabaseService — getAllBoxItemLabels', () {
    test('unions item labels per box and omits unlabelled boxes', () async {
      await db.insertItem(_item('i1', 'b1', labels: [ItemLabel.fragile]));
      await db.insertItem(
          _item('i2', 'b1', labels: [ItemLabel.fragile, ItemLabel.battery]));
      await db.insertItem(_item('i3', 'b2'));

      final labels = await db.getAllBoxItemLabels();
      expect(labels.keys, ['b1']);
      expect(labels['b1'], {ItemLabel.fragile, ItemLabel.battery});
    });
  });
}

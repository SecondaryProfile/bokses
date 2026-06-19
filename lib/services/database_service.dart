import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/box.dart';
import '../models/item.dart';

class DatabaseService {
  static DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();
  DatabaseService.forTesting(); // subclasses use this

  static const _boxesKey = 'local_boxes';
  static const _itemsKey = 'local_items';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<Box>> _readBoxes() async {
    final raw = (await _prefs()).getString(_boxesKey);
    if (raw == null) return [];
    return (json.decode(raw) as List<dynamic>)
        .map((m) => Box.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> _writeBoxes(List<Box> boxes) async {
    await (await _prefs()).setString(
        _boxesKey, json.encode(boxes.map((b) => b.toMap()).toList()));
  }

  Future<List<Item>> _readItems() async {
    final raw = (await _prefs()).getString(_itemsKey);
    if (raw == null) return [];
    return (json.decode(raw) as List<dynamic>)
        .map((m) => Item.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> _writeItems(List<Item> items) async {
    await (await _prefs()).setString(
        _itemsKey, json.encode(items.map((i) => i.toMap()).toList()));
  }

  // ── Boxes ─────────────────────────────────────────────────

  Future<void> insertBox(Box box) async {
    final boxes = await _readBoxes();
    boxes.removeWhere((b) => b.id == box.id);
    boxes.add(box);
    await _writeBoxes(boxes);
  }

  Future<List<Box>> getBoxes() async {
    final boxes = await _readBoxes();
    boxes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return boxes;
  }

  Future<void> updateBox(Box box) => insertBox(box);

  Future<void> deleteBox(String id) async {
    final boxes = await _readBoxes();
    boxes.removeWhere((b) => b.id == id);
    await _writeBoxes(boxes);
    final items = await _readItems();
    items.removeWhere((i) => i.boxId == id);
    await _writeItems(items);
  }

  // ── Items ─────────────────────────────────────────────────

  Future<void> insertItem(Item item) async {
    final items = await _readItems();
    items.removeWhere((i) => i.id == item.id);
    items.add(item);
    await _writeItems(items);
  }

  Future<List<Item>> getItemsForBox(String boxId) async {
    final items = await _readItems();
    final filtered = items.where((i) => i.boxId == boxId).toList();
    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  Future<List<Item>> getAllItems() async {
    final items = await _readItems();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> updateItem(Item item) => insertItem(item);

  Future<void> deleteItem(String id) async {
    final items = await _readItems();
    items.removeWhere((i) => i.id == id);
    await _writeItems(items);
  }

  Future<int> getItemCount(String boxId) async {
    return (await _readItems()).where((i) => i.boxId == boxId).length;
  }

  Future<List<({Item item, Box box})>> searchItems(String query) async {
    if (query.length < 3) return [];
    final lowerQ = query.toLowerCase();
    final items = await _readItems();
    final boxes = await _readBoxes();
    final boxMap = {for (final b in boxes) b.id: b};
    final results = <({Item item, Box box})>[];
    for (final item in items) {
      if (item.name.toLowerCase().contains(lowerQ)) {
        final box = boxMap[item.boxId];
        if (box != null) results.add((item: item, box: box));
      }
    }
    results.sort(
        (a, b) => a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()));
    return results;
  }

  Future<void> clearAll() async {
    final p = await _prefs();
    await p.remove(_boxesKey);
    await p.remove(_itemsKey);
  }
}

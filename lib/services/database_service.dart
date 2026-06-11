// Uses shared_preferences for storage — works identically on iOS, Android, and Web.
// Data is stored as JSON lists under the keys 'bokses_boxes' and 'bokses_items'.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/box.dart';
import '../models/item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  static const _boxesKey = 'bokses_boxes';
  static const _itemsKey = 'bokses_items';

  // ── Internal helpers ─────────────────────────────────────

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Box>> _readBoxes() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_boxesKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((m) => Box.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<void> _writeBoxes(List<Box> boxes) async {
    final prefs = await _prefs;
    await prefs.setString(_boxesKey, json.encode(boxes.map((b) => b.toMap()).toList()));
  }

  Future<List<Item>> _readItems() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_itemsKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((m) => Item.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<void> _writeItems(List<Item> items) async {
    final prefs = await _prefs;
    await prefs.setString(_itemsKey, json.encode(items.map((i) => i.toMap()).toList()));
  }

  // ── Boxes ────────────────────────────────────────────────

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

  Future<void> updateBox(Box box) async {
    final boxes = await _readBoxes();
    final idx = boxes.indexWhere((b) => b.id == box.id);
    if (idx != -1) boxes[idx] = box;
    await _writeBoxes(boxes);
  }

  Future<void> deleteBox(String id) async {
    final boxes = await _readBoxes();
    boxes.removeWhere((b) => b.id == id);
    await _writeBoxes(boxes);

    final items = await _readItems();
    items.removeWhere((i) => i.boxId == id);
    await _writeItems(items);
  }

  // ── Items ────────────────────────────────────────────────

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

  Future<void> updateItem(Item item) async {
    final items = await _readItems();
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) items[idx] = item;
    await _writeItems(items);
  }

  Future<void> deleteItem(String id) async {
    final items = await _readItems();
    items.removeWhere((i) => i.id == id);
    await _writeItems(items);
  }

  Future<int> getItemCount(String boxId) async {
    final items = await _readItems();
    return items.where((i) => i.boxId == boxId).length;
  }

  Future<List<({Item item, Box box})>> searchItems(String query) async {
    if (query.length < 3) return [];
    final q = query.toLowerCase();
    final allItems = await _readItems();
    final allBoxes = await _readBoxes();
    final boxMap = {for (final b in allBoxes) b.id: b};
    final results = <({Item item, Box box})>[];
    for (final item in allItems) {
      if (item.name.toLowerCase().contains(q)) {
        final box = boxMap[item.boxId];
        if (box != null) results.add((item: item, box: box));
      }
    }
    results.sort((a, b) =>
        a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()));
    return results;
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_boxesKey);
    await prefs.remove(_itemsKey);
  }
}

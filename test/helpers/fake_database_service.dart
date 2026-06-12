import 'package:bokses/models/box.dart';
import 'package:bokses/models/item.dart';
import 'package:bokses/services/database_service.dart';

class FakeDatabaseService extends DatabaseService {
  FakeDatabaseService() : super.forTesting();

  final List<Box> _boxes = [];
  final List<Item> _items = [];

  // Expose internals for test assertions
  List<Box> get boxes => List.unmodifiable(_boxes);
  List<Item> get items => List.unmodifiable(_items);

  @override
  Future<void> insertBox(Box box) async {
    _boxes.removeWhere((b) => b.id == box.id);
    _boxes.add(box);
  }

  @override
  Future<List<Box>> getBoxes() async {
    final sorted = List<Box>.from(_boxes);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Future<void> updateBox(Box box) async {
    final idx = _boxes.indexWhere((b) => b.id == box.id);
    if (idx != -1) _boxes[idx] = box;
  }

  @override
  Future<void> deleteBox(String id) async {
    _boxes.removeWhere((b) => b.id == id);
    _items.removeWhere((i) => i.boxId == id);
  }

  @override
  Future<void> insertItem(Item item) async {
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
  }

  @override
  Future<List<Item>> getItemsForBox(String boxId) async {
    final filtered = _items.where((i) => i.boxId == boxId).toList();
    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
  }

  @override
  Future<List<Item>> getAllItems() async {
    final sorted = List<Item>.from(_items);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Future<void> updateItem(Item item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) _items[idx] = item;
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<int> getItemCount(String boxId) async =>
      _items.where((i) => i.boxId == boxId).length;

  @override
  Future<List<({Item item, Box box})>> searchItems(String query) async {
    if (query.length < 3) return [];
    final q = query.toLowerCase();
    final boxMap = {for (final b in _boxes) b.id: b};
    final results = <({Item item, Box box})>[];
    for (final item in _items) {
      if (item.name.toLowerCase().contains(q)) {
        final box = boxMap[item.boxId];
        if (box != null) results.add((item: item, box: box));
      }
    }
    results.sort((a, b) =>
        a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase()));
    return results;
  }

  @override
  Future<void> clearAll() async {
    _boxes.clear();
    _items.clear();
  }
}

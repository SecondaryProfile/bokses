import '../models/box.dart';
import '../models/item.dart';
import 'api_client.dart';

/// Boxes and items now live in Postgres, shared by everyone signed in to
/// this Bokses instance — this just talks to the API server instead of
/// SharedPreferences. The public interface is unchanged, so screens don't
/// need to know the difference.
class DatabaseService {
  static DatabaseService instance = DatabaseService._internal(ApiClient());
  DatabaseService._internal(this._api);
  // Subclasses (e.g. FakeDatabaseService) override every method and never
  // touch _api; an explicit ApiClient lets non-subclassed tests exercise the
  // real request/response plumbing against a mock client instead.
  DatabaseService.forTesting([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  // ── Boxes ─────────────────────────────────────────────────

  Future<void> insertBox(Box box) => _api.put('/boxes/${box.id}', box.toMap());

  Future<List<Box>> getBoxes() async {
    final json = await _api.get('/boxes') as List<dynamic>;
    return json
        .map((m) => Box.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> updateBox(Box box) => insertBox(box);

  Future<void> deleteBox(String id) => _api.delete('/boxes/$id');

  // ── Items ─────────────────────────────────────────────────

  Future<void> insertItem(Item item) => _api.put('/items/${item.id}', item.toMap());

  Future<List<Item>> getItemsForBox(String boxId) async {
    final json = await _api.get('/items', query: {'boxId': boxId}) as List<dynamic>;
    final items = json
        .map((m) => Item.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<List<Item>> getAllItems() async {
    final json = await _api.get('/items') as List<dynamic>;
    final items = json
        .map((m) => Item.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> updateItem(Item item) => insertItem(item);

  Future<void> deleteItem(String id) => _api.delete('/items/$id');

  Future<int> getItemCount(String boxId) async =>
      (await getItemsForBox(boxId)).length;

  Future<List<({Item item, Box box})>> searchItems(String query) async {
    if (query.length < 3) return [];
    final lowerQ = query.toLowerCase();
    final items = await getAllItems();
    final boxes = await getBoxes();
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

  Future<Map<String, Set<ItemLabel>>> getAllBoxItemLabels() async {
    final items = await getAllItems();
    final result = <String, Set<ItemLabel>>{};
    for (final item in items) {
      if (item.labels.isNotEmpty) {
        result.putIfAbsent(item.boxId, () => <ItemLabel>{}).addAll(item.labels);
      }
    }
    return result;
  }

  Future<void> clearAll() => _api.post('/clear-all');
}

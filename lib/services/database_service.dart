import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/box.dart';
import '../models/item.dart';

class DatabaseService {
  static DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();
  DatabaseService.forTesting(); // subclasses use this

  static String serverUrl = 'http://localhost:8743';

  Uri _api(String path) =>
      kIsWeb ? Uri.base.resolve(path) : Uri.parse('$serverUrl$path');

  static const _json = {'Content-Type': 'application/json'};

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Server returned ${res.statusCode}');
    }
    final body = res.body.trimLeft();
    if (body.startsWith('<!') || body.startsWith('<html')) {
      throw Exception('Backend not reachable');
    }
  }

  // ── Boxes ─────────────────────────────────────────────────

  Future<void> insertBox(Box box) async {
    _check(await http.put(_api('/api/boxes/${box.id}'),
        headers: _json, body: json.encode(box.toMap())));
  }

  Future<List<Box>> getBoxes() async {
    final res = await http.get(_api('/api/boxes'));
    _check(res);
    final list = json.decode(res.body) as List<dynamic>;
    return list.map((m) => Box.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<void> updateBox(Box box) async {
    _check(await http.put(_api('/api/boxes/${box.id}'),
        headers: _json, body: json.encode(box.toMap())));
  }

  Future<void> deleteBox(String id) async {
    _check(await http.delete(_api('/api/boxes/$id')));
  }

  // ── Items ─────────────────────────────────────────────────

  Future<void> insertItem(Item item) async {
    _check(await http.put(_api('/api/items/${item.id}'),
        headers: _json, body: json.encode(item.toMap())));
  }

  Future<List<Item>> getItemsForBox(String boxId) async {
    final res = await http.get(_api('/api/items?boxId=$boxId'));
    _check(res);
    final list = json.decode(res.body) as List<dynamic>;
    return list.map((m) => Item.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<List<Item>> getAllItems() async {
    final res = await http.get(_api('/api/items'));
    _check(res);
    final list = json.decode(res.body) as List<dynamic>;
    return list.map((m) => Item.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<void> updateItem(Item item) async {
    _check(await http.put(_api('/api/items/${item.id}'),
        headers: _json, body: json.encode(item.toMap())));
  }

  Future<void> deleteItem(String id) async {
    _check(await http.delete(_api('/api/items/$id')));
  }

  Future<int> getItemCount(String boxId) async {
    final res = await http.get(_api('/api/items/count/$boxId'));
    _check(res);
    return json.decode(res.body) as int;
  }

  Future<List<({Item item, Box box})>> searchItems(String query) async {
    if (query.length < 3) return [];
    final res = await http.get(_api('/api/search?q=${Uri.encodeComponent(query)}'));
    _check(res);
    final list = json.decode(res.body) as List<dynamic>;
    return list.map((m) {
      final entry = m as Map;
      final item = Item.fromMap(Map<String, dynamic>.from(entry['item'] as Map));
      final box = Box.fromMap(Map<String, dynamic>.from(entry['box'] as Map));
      return (item: item, box: box);
    }).toList();
  }

  Future<void> clearAll() async {
    _check(await http.delete(_api('/api/all')));
  }
}

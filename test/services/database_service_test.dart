// Tests for the real DatabaseService — a thin wrapper that turns each call
// into an HTTP request to the Bokses API server (see
// server/lib/src/api.dart). A MockClient stands in for the network so these
// verify DatabaseService sends the right request and parses the response
// correctly, without needing a running server. (Business logic like sorting,
// cascade delete, and search now lives server-side — see server/test/.)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bokses/models/box.dart';
import 'package:bokses/models/item.dart';
import 'package:bokses/services/api_client.dart';
import 'package:bokses/services/database_service.dart';

Box _box(String id, {String? name, int day = 1, bool fragile = false}) => Box(
      id: id,
      name: name ?? 'Box $id',
      fragile: fragile,
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
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late DatabaseService db;

  setUp(() {
    requests = [];
    respond = (_) => http.Response('null', 200);
    final client = MockClient((request) async {
      requests.add(request);
      return respond(request);
    });
    db = DatabaseService.forTesting(ApiClient(client: client));
  });

  group('DatabaseService — boxes', () {
    test('insertBox PUTs to /api/boxes/<id> with the box as JSON', () async {
      await db.insertBox(_box('b1', name: 'Garage', fragile: true));
      expect(requests, hasLength(1));
      final r = requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, '/api/boxes/b1');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['id'], 'b1');
      expect(body['name'], 'Garage');
      expect(body['fragile'], isTrue);
    });

    test('updateBox is the same request as insertBox', () async {
      await db.updateBox(_box('b1', name: 'Renamed'));
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/api/boxes/b1');
    });

    test('getBoxes GETs /api/boxes and parses the list', () async {
      respond = (_) => http.Response(
          jsonEncode([_box('b1', name: 'Attic').toMap(), _box('b2', name: 'Loft').toMap()]),
          200);
      final boxes = await db.getBoxes();
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/boxes');
      expect(boxes.map((b) => b.name), ['Attic', 'Loft']);
    });

    test('deleteBox DELETEs /api/boxes/<id>', () async {
      await db.deleteBox('b1');
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/api/boxes/b1');
    });

    test('a non-2xx response throws ApiException with the server message', () async {
      respond = (_) => http.Response(jsonEncode({'error': 'nope'}), 500);
      expect(db.getBoxes(), throwsA(isA<ApiException>()));
    });
  });

  group('DatabaseService — items', () {
    test('insertItem PUTs to /api/items/<id> with labels', () async {
      await db.insertItem(_item('i1', 'b1', labels: [ItemLabel.fragile, ItemLabel.liquid]));
      final r = requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, '/api/items/i1');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['boxId'], 'b1');
      expect(body['labels'], ['fragile', 'liquid']);
    });

    test('getItemsForBox GETs /api/items?boxId=<id> and sorts oldest first', () async {
      respond = (_) => http.Response(
          jsonEncode([
            _item('late', 'b1', day: 20).toMap(),
            _item('early', 'b1', day: 2).toMap(),
          ]),
          200);
      final items = await db.getItemsForBox('b1');
      expect(requests.single.url.path, '/api/items');
      expect(requests.single.url.queryParameters['boxId'], 'b1');
      expect(items.map((i) => i.id), ['early', 'late']);
    });

    test('getAllItems sorts oldest first', () async {
      respond = (_) => http.Response(
          jsonEncode([
            _item('late', 'b1', day: 20).toMap(),
            _item('early', 'b1', day: 2).toMap(),
          ]),
          200);
      final items = await db.getAllItems();
      expect(items.map((i) => i.id), ['early', 'late']);
    });

    test('deleteItem DELETEs /api/items/<id>', () async {
      await db.deleteItem('i1');
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/api/items/i1');
    });

    test('getItemCount counts the items returned for that box', () async {
      respond = (_) => http.Response(
          jsonEncode([_item('i1', 'b1').toMap(), _item('i2', 'b1').toMap()]), 200);
      expect(await db.getItemCount('b1'), 2);
    });
  });

  group('DatabaseService — search', () {
    test('queries shorter than 3 characters return nothing without a request', () async {
      expect(await db.searchItems('dr'), isEmpty);
      expect(requests, isEmpty);
    });

    test('matches case-insensitively, sorted by item name, with the parent box', () async {
      final boxes = [_box('b1', name: 'Garage'), _box('b2', name: 'Kitchen')];
      final items = [
        _item('i1', 'b1', name: 'Power Drill'),
        _item('i2', 'b2', name: 'drill bits'),
        _item('i3', 'b2', name: 'Whisk'),
      ];
      respond = (request) => request.url.path == '/api/items'
          ? http.Response(jsonEncode(items.map((i) => i.toMap()).toList()), 200)
          : http.Response(jsonEncode(boxes.map((b) => b.toMap()).toList()), 200);

      final results = await db.searchItems('DRILL');
      expect(results.map((r) => r.item.name), ['drill bits', 'Power Drill']);
      expect(results.firstWhere((r) => r.item.id == 'i2').box.name, 'Kitchen');
    });

    test('items whose box no longer exists are skipped', () async {
      final items = [_item('orphan', 'gone', name: 'Orphan drill')];
      respond = (request) => request.url.path == '/api/items'
          ? http.Response(jsonEncode(items.map((i) => i.toMap()).toList()), 200)
          : http.Response('[]', 200);
      expect(await db.searchItems('drill'), isEmpty);
    });
  });

  group('DatabaseService — getAllBoxItemLabels', () {
    test('unions item labels per box and omits unlabelled boxes', () async {
      respond = (_) => http.Response(
          jsonEncode([
            _item('i1', 'b1', labels: [ItemLabel.fragile]).toMap(),
            _item('i2', 'b1', labels: [ItemLabel.fragile, ItemLabel.battery]).toMap(),
            _item('i3', 'b2').toMap(),
          ]),
          200);
      final labels = await db.getAllBoxItemLabels();
      expect(labels.keys, ['b1']);
      expect(labels['b1'], {ItemLabel.fragile, ItemLabel.battery});
    });
  });

  group('DatabaseService — clearAll', () {
    test('POSTs to /api/clear-all', () async {
      await db.clearAll();
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/clear-all');
    });
  });
}

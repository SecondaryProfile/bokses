// Tests for the whole HTTP surface (server/lib/src/api.dart) against a real
// Postgres (see test_helper.dart / BOKSES_TEST_DATABASE_URL), calling the
// shelf Handler in-process rather than over a socket. Store/sorting/cascade
// logic that used to be tested client-side now lives here, next to the code
// that actually implements it.

import 'package:test/test.dart';

import 'package:bokses_server/src/api.dart';
import 'package:bokses_server/src/store.dart';

import 'test_helper.dart';

void main() {
  late Store store;
  late TestClient client;

  setUpAll(() async {
    final config = testConfig();
    await resetDatabase(config);
    store = await Store.connect(config);
  });

  tearDownAll(() => store.close());

  setUp(() async {
    await resetDatabase(testConfig());
    client = TestClient(buildHandler(store));
  });

  Future<void> setupRoot({String username = 'admin', String password = 'root-password'}) async {
    final r = await client.post('/api/setup', {'username': username, 'password': password});
    expect(r.status, 200, reason: 'setup should succeed: ${r.json}');
  }

  group('setup', () {
    test('needsSetup is true with no accounts, false after one exists', () async {
      expect((await client.get('/api/setup')).json['needsSetup'], isTrue);
      await setupRoot();
      expect((await client.get('/api/setup')).json['needsSetup'], isFalse);
    });

    test('signupsEnabled defaults to true once setup is done', () async {
      await setupRoot();
      expect((await client.get('/api/setup')).json['signupsEnabled'], isTrue);
    });

    test('creates a root account and signs it in via cookie', () async {
      final r = await client.post('/api/setup', {'username': 'admin', 'password': 'root-password'});
      expect(r.status, 200);
      expect(r.json['isRoot'], isTrue);
      expect((await client.get('/api/auth/me')).json['username'], 'admin');
    });

    test('a second setup attempt is rejected', () async {
      await setupRoot();
      final r = await client.post('/api/setup', {'username': 'other', 'password': 'other-password'});
      expect(r.status, 409);
    });

    test('missing username or password is rejected', () async {
      final r = await client.post('/api/setup', {'username': '', 'password': 'x'});
      expect(r.status, 400);
    });
  });

  group('auth', () {
    setUp(setupRoot);

    test('signup creates a non-root account when signups are enabled', () async {
      final r = await client.post('/api/auth/signup', {'username': 'joe', 'password': 'joe-password'});
      expect(r.status, 200);
      expect(r.json['isRoot'], isFalse);
    });

    test('signup is blocked when signups are disabled', () async {
      await client.put('/api/settings/signups', {'enabled': false});
      client.forgetSession();
      final r = await client.post('/api/auth/signup', {'username': 'joe', 'password': 'joe-password'});
      expect(r.status, 403);
    });

    test('signup rejects a taken username', () async {
      client.forgetSession();
      final r = await client.post('/api/auth/signup', {'username': 'admin', 'password': 'whatever1'});
      expect(r.status, 409);
    });

    test('login with the wrong password is rejected', () async {
      client.forgetSession();
      final r = await client.post('/api/auth/login', {'username': 'admin', 'password': 'wrong'});
      expect(r.status, 401);
    });

    test('login with the right password signs in', () async {
      client.forgetSession();
      final r = await client.post('/api/auth/login', {'username': 'admin', 'password': 'root-password'});
      expect(r.status, 200);
      expect((await client.get('/api/auth/me')).json['username'], 'admin');
    });

    test('too many failed logins are rate-limited', () async {
      client.forgetSession();
      for (var i = 0; i < 10; i++) {
        await client.post('/api/auth/login', {'username': 'admin', 'password': 'wrong'});
      }
      final r = await client.post('/api/auth/login', {'username': 'admin', 'password': 'wrong'});
      expect(r.status, 429);
    });

    test('logout ends the session', () async {
      await client.post('/api/auth/logout');
      expect((await client.get('/api/auth/me')).status, 401);
    });

    test('change-password requires the correct current password', () async {
      final r = await client.post(
          '/api/auth/change-password', {'currentPassword': 'wrong', 'newPassword': 'new-password'});
      expect(r.status, 401);
    });

    test('change-password succeeds and signs out other sessions', () async {
      final r = await client.post('/api/auth/change-password',
          {'currentPassword': 'root-password', 'newPassword': 'new-password'});
      expect(r.status, 200);

      final other = TestClient(buildHandler(store));
      final login = await other.post('/api/auth/login', {'username': 'admin', 'password': 'root-password'});
      expect(login.status, 401, reason: 'old password should no longer work');

      final relogin = await other.post('/api/auth/login', {'username': 'admin', 'password': 'new-password'});
      expect(relogin.status, 200);
    });
  });

  group('accounts (root only)', () {
    setUp(setupRoot);

    test('a non-root account cannot list, create, or delete accounts', () async {
      await client.post('/api/auth/signup', {'username': 'joe', 'password': 'joe-password'});
      expect((await client.get('/api/accounts')).status, 403);
      expect((await client.post('/api/accounts', {'username': 'x', 'password': 'x12345678'})).status, 403);
    });

    test('root creates, lists, and deletes an account', () async {
      final created = await client.post('/api/accounts', {'username': 'joe', 'password': 'joe-password'});
      expect(created.status, 201);
      final id = created.json['id'] as String;

      final list = await client.get('/api/accounts');
      expect((list.json as List).map((a) => a['username']), containsAll(['admin', 'joe']));

      expect((await client.delete('/api/accounts/$id')).status, 200);
      final after = await client.get('/api/accounts');
      expect((after.json as List).map((a) => a['username']), isNot(contains('joe')));
    });

    test('root cannot delete the root account', () async {
      final me = await client.get('/api/auth/me');
      final r = await client.delete('/api/accounts/${me.json['id']}');
      expect(r.status, 400);
    });

    test('root resets another account\'s password', () async {
      final created = await client.post('/api/accounts', {'username': 'joe', 'password': 'joe-password'});
      final id = created.json['id'] as String;
      expect((await client.post('/api/accounts/$id/reset-password', {'password': 'brand-new'})).status, 200);

      final joe = TestClient(buildHandler(store));
      expect((await joe.post('/api/auth/login', {'username': 'joe', 'password': 'joe-password'})).status, 401);
      expect((await joe.post('/api/auth/login', {'username': 'joe', 'password': 'brand-new'})).status, 200);
    });

    test('toggling signups is reflected in GET /api/setup', () async {
      await client.put('/api/settings/signups', {'enabled': false});
      expect((await client.get('/api/setup')).json['signupsEnabled'], isFalse);
    });
  });

  group('boxes and items', () {
    setUp(setupRoot);

    test('unauthenticated requests are rejected', () async {
      client.forgetSession();
      expect((await client.get('/api/boxes')).status, 401);
      expect((await client.put('/api/boxes/b1', {'name': 'Garage'})).status, 401);
    });

    test('a box round-trips through PUT and GET', () async {
      await client.put('/api/boxes/b1',
          {'name': 'Garage', 'description': 'Tools', 'fragile': false, 'createdAt': '2024-01-01T00:00:00.000Z'});
      final boxes = (await client.get('/api/boxes')).json as List;
      expect(boxes, hasLength(1));
      expect(boxes.single['name'], 'Garage');
    });

    test('boxes come back oldest first regardless of insert order', () async {
      await client.put('/api/boxes/late',
          {'name': 'Late', 'createdAt': '2024-01-20T00:00:00.000Z'});
      await client.put('/api/boxes/early',
          {'name': 'Early', 'createdAt': '2024-01-02T00:00:00.000Z'});
      final boxes = (await client.get('/api/boxes')).json as List;
      expect(boxes.map((b) => b['id']), ['early', 'late']);
    });

    test('an item round-trips and can be filtered by box', () async {
      await client.put('/api/boxes/b1', {'name': 'Garage', 'createdAt': '2024-01-01T00:00:00.000Z'});
      await client.put('/api/items/i1',
          {'name': 'Drill', 'boxId': 'b1', 'createdAt': '2024-01-01T00:00:00.000Z', 'labels': ['battery']});
      final items = (await client.get('/api/items?boxId=b1')).json as List;
      expect(items, hasLength(1));
      expect(items.single['name'], 'Drill');
      expect(items.single['labels'], ['battery']);
    });

    test('deleting a box also deletes its items', () async {
      await client.put('/api/boxes/b1', {'name': 'Garage', 'createdAt': '2024-01-01T00:00:00.000Z'});
      await client.put('/api/items/i1', {'name': 'Drill', 'boxId': 'b1', 'createdAt': '2024-01-01T00:00:00.000Z'});
      await client.delete('/api/boxes/b1');
      final items = (await client.get('/api/items')).json as List;
      expect(items, isEmpty);
    });

    test('clear-all removes every box and item', () async {
      await client.put('/api/boxes/b1', {'name': 'Garage', 'createdAt': '2024-01-01T00:00:00.000Z'});
      await client.put('/api/items/i1', {'name': 'Drill', 'boxId': 'b1', 'createdAt': '2024-01-01T00:00:00.000Z'});
      await client.post('/api/clear-all');
      expect((await client.get('/api/boxes')).json, isEmpty);
      expect((await client.get('/api/items')).json, isEmpty);
    });
  });
}

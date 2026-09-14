import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uuid/uuid.dart';

/// A tiny in-memory stand-in for the real Bokses API server
/// (server/lib/src/api.dart), driving a [MockClient] so widget tests can
/// exercise the real [AuthService]/[ApiClient] request/response plumbing
/// without a network. Mirrors the real server's status codes and error
/// messages so these tests catch real regressions, not just changes to this
/// fake.
class FakeUser {
  final String id;
  String username;
  String password;
  final bool isRoot;
  FakeUser({required this.id, required this.username, required this.password, this.isRoot = false});
}

class FakeApi {
  final Map<String, FakeUser> users = {};
  String? signedInAs;
  bool allowSignups = true;
  bool offline = false;
  final List<http.Request> requests = [];

  static const _uuid = Uuid();

  FakeUser addUser(String username, String password, {bool isRoot = false}) {
    final user = FakeUser(id: _uuid.v4(), username: username, password: password, isRoot: isRoot);
    users[username] = user;
    return user;
  }

  http.Client get client => MockClient((request) async {
        requests.add(request);
        if (offline) throw const SocketException('Failed host lookup');
        return _handle(request);
      });

  Map<String, dynamic> _body(http.Request request) {
    if (request.body.isEmpty) return {};
    return jsonDecode(request.body) as Map<String, dynamic>;
  }

  http.Response _json(Object data, [int status = 200]) =>
      http.Response(jsonEncode(data), status, headers: {'content-type': 'application/json'});

  http.Response _error(int status, String message) => _json({'error': message}, status);

  Map<String, dynamic> _accountJson(FakeUser u) =>
      {'id': u.id, 'username': u.username, 'isRoot': u.isRoot};

  FakeUser? get _me => signedInAs == null ? null : users[signedInAs];

  http.Response _handle(http.Request request) {
    final path = request.url.path.replaceFirst('/api', '');
    final method = request.method;

    if (method == 'GET' && path == '/setup') {
      final needsSetup = users.isEmpty;
      return _json({
        'needsSetup': needsSetup,
        'signupsEnabled': needsSetup ? false : allowSignups,
      });
    }

    if (method == 'POST' && path == '/setup') {
      if (users.isNotEmpty) return _error(409, 'Setup has already been completed');
      final body = _body(request);
      final username = (body['username'] as String? ?? '').trim();
      final password = body['password'] as String? ?? '';
      if (username.isEmpty || password.isEmpty) {
        return _error(400, 'Username and password are required');
      }
      final user = addUser(username, password, isRoot: true);
      signedInAs = username;
      return _json(_accountJson(user));
    }

    if (method == 'POST' && path == '/auth/signup') {
      if (users.isEmpty) return _error(409, 'Setup has not been completed yet');
      if (!allowSignups) return _error(403, 'Sign-ups are currently disabled');
      final body = _body(request);
      final username = (body['username'] as String? ?? '').trim();
      final password = body['password'] as String? ?? '';
      if (username.isEmpty || password.isEmpty) {
        return _error(400, 'Username and password are required');
      }
      if (users.containsKey(username)) return _error(409, 'That username is already taken');
      final user = addUser(username, password);
      signedInAs = username;
      return _json(_accountJson(user));
    }

    if (method == 'POST' && path == '/auth/login') {
      final body = _body(request);
      final username = (body['username'] as String? ?? '').trim();
      final password = body['password'] as String? ?? '';
      final user = users[username];
      if (user == null || user.password != password) {
        return _error(401, 'Invalid username or password');
      }
      signedInAs = username;
      return _json(_accountJson(user));
    }

    if (method == 'POST' && path == '/auth/logout') {
      signedInAs = null;
      return _json({'ok': true});
    }

    if (method == 'GET' && path == '/auth/me') {
      final me = _me;
      if (me == null) return _error(401, 'Not signed in');
      return _json(_accountJson(me));
    }

    if (method == 'POST' && path == '/auth/change-password') {
      final me = _me;
      if (me == null) return _error(401, 'Not signed in');
      final body = _body(request);
      final current = body['currentPassword'] as String? ?? '';
      final next = body['newPassword'] as String? ?? '';
      if (me.password != current) return _error(401, 'Current password is incorrect');
      if (next.isEmpty) return _error(400, 'A new password is required');
      me.password = next;
      return _json({'ok': true});
    }

    final me = _me;
    if (path == '/accounts' && method == 'GET') {
      if (me == null) return _error(401, 'Not signed in');
      if (!me.isRoot) return _error(403, 'Root only');
      return _json(users.values.map(_accountJson).toList());
    }

    if (path == '/accounts' && method == 'POST') {
      if (me == null) return _error(401, 'Not signed in');
      if (!me.isRoot) return _error(403, 'Root only');
      final body = _body(request);
      final username = (body['username'] as String? ?? '').trim();
      final password = body['password'] as String? ?? '';
      if (username.isEmpty || password.isEmpty) {
        return _error(400, 'Username and password are required');
      }
      if (users.containsKey(username)) return _error(409, 'That username is already taken');
      final user = addUser(username, password);
      return _json(_accountJson(user), 201);
    }

    final deleteMatch = RegExp(r'^/accounts/([^/]+)$').firstMatch(path);
    if (deleteMatch != null && method == 'DELETE') {
      if (me == null) return _error(401, 'Not signed in');
      if (!me.isRoot) return _error(403, 'Root only');
      final id = deleteMatch.group(1)!;
      FakeUser? target;
      for (final u in users.values) {
        if (u.id == id) target = u;
      }
      if (target == null) return _error(404, 'No such account');
      if (target.isRoot) return _error(400, "Root can't be deleted");
      users.remove(target.username);
      return _json({'ok': true});
    }

    final resetMatch = RegExp(r'^/accounts/([^/]+)/reset-password$').firstMatch(path);
    if (resetMatch != null && method == 'POST') {
      if (me == null) return _error(401, 'Not signed in');
      if (!me.isRoot) return _error(403, 'Root only');
      final id = resetMatch.group(1)!;
      FakeUser? target;
      for (final u in users.values) {
        if (u.id == id) target = u;
      }
      if (target == null) return _error(404, 'No such account');
      final body = _body(request);
      target.password = body['password'] as String? ?? '';
      return _json({'ok': true});
    }

    if (path == '/settings/signups' && method == 'PUT') {
      if (me == null) return _error(401, 'Not signed in');
      if (!me.isRoot) return _error(403, 'Root only');
      final body = _body(request);
      allowSignups = body['enabled'] == true;
      return _json({'ok': true});
    }

    return _error(404, 'Not found');
  }
}

class SocketException implements Exception {
  final String message;
  const SocketException(this.message);
  @override
  String toString() => 'SocketException: $message';
}

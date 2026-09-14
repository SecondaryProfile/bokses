import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import 'package:bokses_server/src/config.dart';

/// Test Postgres connection info, from BOKSES_TEST_DATABASE_URL (see CI's
/// "server" job and README-adjacent tool/coverage notes). Locally, point it
/// at a throwaway Postgres container — never the app's own compose stack.
Config testConfig() {
  final raw = Platform.environment['BOKSES_TEST_DATABASE_URL'];
  if (raw == null) {
    throw StateError(
      'BOKSES_TEST_DATABASE_URL is not set. Point it at a throwaway '
      'Postgres, e.g. postgres://bokses:ci-only-password@localhost:5433/bokses_test',
    );
  }
  final uri = Uri.parse(raw);
  final userInfo = uri.userInfo.split(':');
  return Config(
    dbHost: uri.host,
    dbPort: uri.port,
    dbName: uri.path.replaceFirst('/', ''),
    dbUser: userInfo[0],
    dbPassword: userInfo.length > 1 ? userInfo[1] : '',
  );
}

/// Wipes every table so each test starts from a clean slate. Uses its own
/// connection, independent of the Store under test.
Future<void> resetDatabase(Config config) async {
  final conn = await Connection.open(
    Endpoint(
      host: config.dbHost,
      port: config.dbPort,
      database: config.dbName,
      username: config.dbUser,
      password: config.dbPassword,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  try {
    await conn.execute('''
      TRUNCATE TABLE sessions, items, boxes, settings, accounts RESTART IDENTITY CASCADE
    ''');
  } catch (_) {
    // Tables may not exist yet on the very first run, before Store._migrate()
    // has created them — nothing to reset in that case.
  } finally {
    await conn.close();
  }
}

/// Thin wrapper around a [Handler] that remembers the session cookie between
/// requests, like a browser would.
class TestClient {
  final Handler _handler;
  String? _cookie;

  TestClient(this._handler);

  /// Drops the remembered session cookie, simulating a signed-out browser.
  void forgetSession() => _cookie = null;

  Future<TestResponse> get(String path) => _send('GET', path);
  Future<TestResponse> delete(String path) => _send('DELETE', path);
  Future<TestResponse> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);
  Future<TestResponse> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body);

  Future<TestResponse> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (_cookie != null) headers['cookie'] = _cookie!;
    final request = Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    final response = await _handler(request);
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      // Only the name=value pair matters for replaying it on the next
      // request; drop the Path/HttpOnly/etc attributes.
      final pair = setCookie.split(';').first;
      _cookie = pair.endsWith('=') ? null : pair;
    }
    final text = await response.readAsString();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    return TestResponse(response.statusCode, decoded);
  }
}

class TestResponse {
  final int status;
  final dynamic json;
  TestResponse(this.status, this.json);
}

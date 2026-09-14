import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'rate_limiter.dart';
import 'security.dart';
import 'store.dart';

const _sessionCookieName = 'session';
const _sessionMaxAgeSeconds = 30 * 24 * 60 * 60; // 30 days

Response _json(Object data, {int status = 200, Map<String, String>? headers}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json', ...?headers},
  );
}

Response _error(int status, String message) => _json({'error': message}, status: status);

String? _sessionToken(Request request) {
  final header = request.headers['cookie'];
  if (header == null) return null;
  for (final part in header.split(';')) {
    final eq = part.indexOf('=');
    if (eq == -1) continue;
    final name = part.substring(0, eq).trim();
    if (name == _sessionCookieName) return part.substring(eq + 1).trim();
  }
  return null;
}

bool _wantsSecureCookie(Request request) =>
    request.headers['x-forwarded-proto']?.toLowerCase() == 'https';

String _setCookieHeader(String token, {required bool secure}) {
  final parts = [
    '$_sessionCookieName=$token',
    'Path=/',
    'HttpOnly',
    'SameSite=Strict',
    'Max-Age=$_sessionMaxAgeSeconds',
  ];
  if (secure) parts.add('Secure');
  return parts.join('; ');
}

String _clearCookieHeader({required bool secure}) {
  final parts = ['$_sessionCookieName=', 'Path=/', 'HttpOnly', 'SameSite=Strict', 'Max-Age=0'];
  if (secure) parts.add('Secure');
  return parts.join('; ');
}

Map<String, dynamic> _accountJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'username': row['username'],
      'isRoot': row['is_root'] as bool,
    };

Map<String, dynamic> _boxJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'name': row['name'],
      'description': row['description'],
      'fragile': row['fragile'],
      'createdAt': (row['created_at'] as DateTime).toIso8601String(),
    };

Map<String, dynamic> _itemJson(Map<String, dynamic> row) => {
      'id': row['id'],
      'name': row['name'],
      'photoPath': row['photo_path'],
      'webPhoto': row['web_photo'],
      'boxId': row['box_id'],
      'createdAt': (row['created_at'] as DateTime).toIso8601String(),
      'labels': row['labels'],
    };

/// Builds the full request handler: middleware (session lookup) wrapped
/// around the route table.
Handler buildHandler(Store store) {
  final loginLimiter = RateLimiter(maxAttempts: 10, window: const Duration(minutes: 15));
  final router = Router();

  Future<Map<String, dynamic>> readJsonBody(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Map<String, dynamic>? currentAccount(Request request) =>
      request.context['account'] as Map<String, dynamic>?;

  // ── Health & setup ────────────────────────────────────────────────

  router.get('/api/health', (Request request) => _json({'ok': true}));

  router.get('/api/setup', (Request request) async {
    final needsSetup = !await store.hasAnyAccount();
    final signupsEnabled = needsSetup ? false : await store.signupsEnabled();
    return _json({'needsSetup': needsSetup, 'signupsEnabled': signupsEnabled});
  });

  router.post('/api/setup', (Request request) async {
    if (await store.hasAnyAccount()) {
      return _error(409, 'Setup has already been completed');
    }
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final username = (body['username'] as String?)?.trim() ?? '';
    final password = body['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      return _error(400, 'Username and password are required');
    }
    final account = await store.createAccount(
      username: username,
      password: password,
      isRoot: true,
    );
    final token = await store.createSession(account['id'] as String);
    return _json(
      {...account},
      headers: {
        'set-cookie': _setCookieHeader(token, secure: _wantsSecureCookie(request)),
      },
    );
  });

  // ── Auth ──────────────────────────────────────────────────────────

  router.post('/api/auth/signup', (Request request) async {
    if (!await store.hasAnyAccount()) {
      return _error(409, 'Setup has not been completed yet');
    }
    if (!await store.signupsEnabled()) {
      return _error(403, 'Sign-ups are currently disabled');
    }
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final username = (body['username'] as String?)?.trim() ?? '';
    final password = body['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      return _error(400, 'Username and password are required');
    }
    if (await store.usernameTaken(username)) {
      return _error(409, 'That username is already taken');
    }
    final account = await store.createAccount(
      username: username,
      password: password,
      isRoot: false,
    );
    final token = await store.createSession(account['id'] as String);
    return _json(
      {...account},
      headers: {
        'set-cookie': _setCookieHeader(token, secure: _wantsSecureCookie(request)),
      },
    );
  });

  router.post('/api/auth/login', (Request request) async {
    final ip = request.headers['x-real-ip'] ??
        request.headers['x-forwarded-for'] ??
        (request.context['shelf.io.connection_info'] as dynamic)?.remoteAddress?.address ??
        'unknown';
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final username = (body['username'] as String?)?.trim() ?? '';
    final password = body['password'] as String? ?? '';

    if (loginLimiter.isLimited('ip:$ip') || loginLimiter.isLimited('user:$username')) {
      return _error(429, 'Too many attempts. Try again later.');
    }

    final account = await store.verifyCredentials(username, password);
    if (account == null) {
      loginLimiter.recordFailure('ip:$ip');
      loginLimiter.recordFailure('user:$username');
      return _error(401, 'Invalid username or password');
    }
    loginLimiter.reset('ip:$ip');
    loginLimiter.reset('user:$username');

    final token = await store.createSession(account['id'] as String);
    return _json(
      _accountJson(account),
      headers: {
        'set-cookie': _setCookieHeader(token, secure: _wantsSecureCookie(request)),
      },
    );
  });

  router.post('/api/auth/logout', (Request request) async {
    final token = _sessionToken(request);
    if (token != null) await store.deleteSessionByToken(token);
    return _json(
      {'ok': true},
      headers: {'set-cookie': _clearCookieHeader(secure: _wantsSecureCookie(request))},
    );
  });

  router.get('/api/auth/me', (Request request) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    return _json(_accountJson(account));
  });

  router.post('/api/auth/change-password', (Request request) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final current = body['currentPassword'] as String? ?? '';
    final next = body['newPassword'] as String? ?? '';
    if (next.isEmpty) return _error(400, 'A new password is required');
    if (!Security.verifyPassword(current, account['password_hash'] as String)) {
      return _error(401, 'Current password is incorrect');
    }
    final id = account['id'] as String;
    await store.setPassword(id, next);
    // Signs out every other device; a fresh session keeps this one signed in.
    await store.deleteAllSessionsForAccount(id);
    final token = await store.createSession(id);
    return _json(
      {'ok': true},
      headers: {'set-cookie': _setCookieHeader(token, secure: _wantsSecureCookie(request))},
    );
  });

  // ── Accounts (root only) ────────────────────────────────────────────

  router.get('/api/accounts', (Request request) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    if (account['is_root'] != true) return _error(403, 'Root only');
    final rows = await store.listAccounts();
    return _json(rows.map(_accountJson).toList());
  });

  router.post('/api/accounts', (Request request) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    if (account['is_root'] != true) return _error(403, 'Root only');
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final username = (body['username'] as String?)?.trim() ?? '';
    final password = body['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      return _error(400, 'Username and password are required');
    }
    if (await store.usernameTaken(username)) {
      return _error(409, 'That username is already taken');
    }
    final created = await store.createAccount(username: username, password: password, isRoot: false);
    return _json(created, status: 201);
  });

  router.delete('/api/accounts/<id>', (Request request, String id) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    if (account['is_root'] != true) return _error(403, 'Root only');
    final target = await store.findAccountById(id);
    if (target == null) return _error(404, 'No such account');
    if (target['is_root'] == true) return _error(400, "Root can't be deleted");
    await store.deleteAccount(id);
    return _json({'ok': true});
  });

  router.post('/api/accounts/<id>/reset-password', (Request request, String id) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    if (account['is_root'] != true) return _error(403, 'Root only');
    final target = await store.findAccountById(id);
    if (target == null) return _error(404, 'No such account');
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    final password = body['password'] as String? ?? '';
    if (password.isEmpty) return _error(400, 'A password is required');
    await store.setPassword(id, password);
    await store.deleteAllSessionsForAccount(id);
    return _json({'ok': true});
  });

  router.put('/api/settings/signups', (Request request) async {
    final account = currentAccount(request);
    if (account == null) return _error(401, 'Not signed in');
    if (account['is_root'] != true) return _error(403, 'Root only');
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    await store.setSignupsEnabled(body['enabled'] == true);
    return _json({'ok': true});
  });

  // ── Boxes & items (any signed-in account) ───────────────────────────

  Response? requireAuth(Request request) {
    if (currentAccount(request) == null) return _error(401, 'Not signed in');
    return null;
  }

  router.get('/api/boxes', (Request request) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    final rows = await store.getBoxes();
    return _json(rows.map(_boxJson).toList());
  });

  router.put('/api/boxes/<id>', (Request request, String id) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    body['id'] = id;
    await store.upsertBox(body, currentAccount(request)!['id'] as String);
    return _json({'ok': true});
  });

  router.delete('/api/boxes/<id>', (Request request, String id) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    await store.deleteBox(id);
    return _json({'ok': true});
  });

  router.get('/api/items', (Request request) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    final boxId = request.url.queryParameters['boxId'];
    final rows = await store.getAllItems();
    final filtered = boxId == null ? rows : rows.where((r) => r['box_id'] == boxId).toList();
    return _json(filtered.map(_itemJson).toList());
  });

  router.put('/api/items/<id>', (Request request, String id) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    Map<String, dynamic> body;
    try {
      body = await readJsonBody(request);
    } catch (_) {
      return _error(400, 'Invalid request body');
    }
    body['id'] = id;
    await store.upsertItem(body, currentAccount(request)!['id'] as String);
    return _json({'ok': true});
  });

  router.delete('/api/items/<id>', (Request request, String id) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    await store.deleteItem(id);
    return _json({'ok': true});
  });

  router.post('/api/clear-all', (Request request) async {
    final unauth = requireAuth(request);
    if (unauth != null) return unauth;
    await store.clearAll();
    return _json({'ok': true});
  });

  router.all('/<ignored|.*>', (Request request) => _error(404, 'Not found'));

  // ── Middleware: attach the signed-in account (if any) to the request ──

  Handler sessionMiddleware(Handler inner) {
    return (Request request) async {
      final token = _sessionToken(request);
      final account = token == null ? null : await store.findAccountByToken(token);
      return inner(request.change(context: {'account': account}));
    };
  }

  return const Pipeline().addMiddleware(sessionMiddleware).addHandler(router.call);
}

import 'dart:async';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'security.dart';

const _uuid = Uuid();
const _sessionTtl = Duration(days: 30);

/// Everything the API needs from Postgres: accounts, sessions, the
/// signups-enabled flag, and the shared boxes/items data. One class, one
/// connection — this is a small single-instance app, not a service mesh.
class Store {
  final Connection _db;

  Store._(this._db);

  static Future<Store> connect(Config config) async {
    Connection? conn;
    // Postgres' own healthcheck gates container startup, but give it a few
    // extra retries in case of a slow first boot.
    for (var attempt = 1; attempt <= 10; attempt++) {
      try {
        conn = await Connection.open(
          Endpoint(
            host: config.dbHost,
            port: config.dbPort,
            database: config.dbName,
            username: config.dbUser,
            password: config.dbPassword,
          ),
          settings: const ConnectionSettings(sslMode: SslMode.disable),
        );
        break;
      } catch (_) {
        if (attempt == 10) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    final store = Store._(conn!);
    await store._migrate();
    return store;
  }

  Future<void> close() => _db.close();

  Future<void> _migrate() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        is_root BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    ''');
    // The database itself guarantees there is only ever one root account.
    await _db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS accounts_single_root
        ON accounts ((is_root)) WHERE is_root
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        expires_at TIMESTAMPTZ NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS boxes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        fragile BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL,
        created_by TEXT REFERENCES accounts(id) ON DELETE SET NULL,
        updated_by TEXT REFERENCES accounts(id) ON DELETE SET NULL
      )
    ''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        photo_path TEXT,
        web_photo BOOLEAN NOT NULL DEFAULT FALSE,
        box_id TEXT NOT NULL REFERENCES boxes(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL,
        labels TEXT[] NOT NULL DEFAULT '{}',
        created_by TEXT REFERENCES accounts(id) ON DELETE SET NULL,
        updated_by TEXT REFERENCES accounts(id) ON DELETE SET NULL
      )
    ''');
  }

  // ── Setup / accounts ──────────────────────────────────────────────

  Future<bool> hasAnyAccount() async {
    final r = await _db.execute('SELECT 1 FROM accounts LIMIT 1');
    return r.isNotEmpty;
  }

  Future<bool> signupsEnabled() async {
    final r = await _db.execute(
      Sql.named("SELECT value FROM settings WHERE key = 'signups_enabled'"),
    );
    if (r.isEmpty) return true;
    return r.first.toColumnMap()['value'] == 'true';
  }

  Future<void> setSignupsEnabled(bool enabled) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO settings (key, value) VALUES ('signups_enabled', @v)
        ON CONFLICT (key) DO UPDATE SET value = @v
      '''),
      parameters: {'v': enabled.toString()},
    );
  }

  /// Creates an account. [isRoot] must only ever be true for the very first
  /// (setup) account — the unique index enforces that at the database level
  /// regardless of what the caller does.
  Future<Map<String, dynamic>> createAccount({
    required String username,
    required String password,
    required bool isRoot,
  }) async {
    final id = _uuid.v4();
    final hash = Security.hashPassword(password);
    await _db.execute(
      Sql.named('''
        INSERT INTO accounts (id, username, password_hash, is_root)
        VALUES (@id, @username, @hash, @isRoot)
      '''),
      parameters: {
        'id': id,
        'username': username,
        'hash': hash,
        'isRoot': isRoot,
      },
    );
    return {'id': id, 'username': username, 'isRoot': isRoot};
  }

  Future<Map<String, dynamic>?> _findAccountByUsername(String username) async {
    final r = await _db.execute(
      Sql.named('SELECT * FROM accounts WHERE username = @u'),
      parameters: {'u': username},
    );
    if (r.isEmpty) return null;
    return r.first.toColumnMap();
  }

  Future<Map<String, dynamic>?> findAccountById(String id) async {
    final r = await _db.execute(
      Sql.named('SELECT * FROM accounts WHERE id = @id'),
      parameters: {'id': id},
    );
    if (r.isEmpty) return null;
    return r.first.toColumnMap();
  }

  Future<List<Map<String, dynamic>>> listAccounts() async {
    final r = await _db.execute(
      'SELECT id, username, is_root, created_at FROM accounts ORDER BY created_at',
    );
    return r.map((row) => row.toColumnMap()).toList();
  }

  Future<bool> usernameTaken(String username) async {
    return await _findAccountByUsername(username) != null;
  }

  /// Verifies credentials, always doing the same Argon2id work whether or
  /// not the username exists, so response timing doesn't reveal which
  /// accounts are registered.
  Future<Map<String, dynamic>?> verifyCredentials(
      String username, String password) async {
    final account = await _findAccountByUsername(username);
    final hash = account?['password_hash'] as String? ?? Security.dummyHash;
    final ok = Security.verifyPassword(password, hash);
    if (account != null && ok) return account;
    return null;
  }

  Future<void> deleteAccount(String id) async {
    await _db.execute(
      Sql.named('DELETE FROM accounts WHERE id = @id AND is_root = FALSE'),
      parameters: {'id': id},
    );
  }

  Future<void> setPassword(String accountId, String newPassword) async {
    final hash = Security.hashPassword(newPassword);
    await _db.execute(
      Sql.named('UPDATE accounts SET password_hash = @h WHERE id = @id'),
      parameters: {'h': hash, 'id': accountId},
    );
  }

  // ── Sessions ──────────────────────────────────────────────────────

  Future<String> createSession(String accountId) async {
    final token = Security.generateToken();
    await _db.execute(
      Sql.named('''
        INSERT INTO sessions (token_hash, account_id, expires_at)
        VALUES (@hash, @accountId, @expiresAt)
      '''),
      parameters: {
        'hash': Security.hashToken(token),
        'accountId': accountId,
        'expiresAt': DateTime.now().toUtc().add(_sessionTtl),
      },
    );
    return token;
  }

  Future<Map<String, dynamic>?> findAccountByToken(String token) async {
    final r = await _db.execute(
      Sql.named('''
        SELECT a.* FROM sessions s
        JOIN accounts a ON a.id = s.account_id
        WHERE s.token_hash = @hash AND s.expires_at > now()
      '''),
      parameters: {'hash': Security.hashToken(token)},
    );
    if (r.isEmpty) return null;
    return r.first.toColumnMap();
  }

  Future<void> deleteSessionByToken(String token) async {
    await _db.execute(
      Sql.named('DELETE FROM sessions WHERE token_hash = @hash'),
      parameters: {'hash': Security.hashToken(token)},
    );
  }

  Future<void> deleteAllSessionsForAccount(String accountId) async {
    await _db.execute(
      Sql.named('DELETE FROM sessions WHERE account_id = @id'),
      parameters: {'id': accountId},
    );
  }

  // ── Boxes ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBoxes() async {
    final r = await _db.execute('SELECT * FROM boxes ORDER BY created_at');
    return r.map((row) => row.toColumnMap()).toList();
  }

  Future<void> upsertBox(Map<String, dynamic> box, String accountId) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO boxes (id, name, description, fragile, created_at, created_by, updated_by)
        VALUES (@id, @name, @description, @fragile, @createdAt, @accountId, @accountId)
        ON CONFLICT (id) DO UPDATE SET
          name = @name, description = @description, fragile = @fragile,
          updated_by = @accountId
      '''),
      parameters: {
        'id': box['id'],
        'name': box['name'],
        'description': box['description'],
        'fragile': box['fragile'] ?? false,
        'createdAt': DateTime.parse(box['createdAt'] as String),
        'accountId': accountId,
      },
    );
  }

  Future<void> deleteBox(String id) async {
    await _db.execute(
      Sql.named('DELETE FROM boxes WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  // ── Items ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final r = await _db.execute('SELECT * FROM items ORDER BY created_at');
    return r.map((row) => row.toColumnMap()).toList();
  }

  Future<void> upsertItem(Map<String, dynamic> item, String accountId) async {
    final labels = ((item['labels'] as List<dynamic>?) ?? [])
        .map((l) => l.toString())
        .toList();
    await _db.execute(
      Sql.named('''
        INSERT INTO items (id, name, photo_path, web_photo, box_id, created_at, labels, created_by, updated_by)
        VALUES (@id, @name, @photoPath, @webPhoto, @boxId, @createdAt, @labels, @accountId, @accountId)
        ON CONFLICT (id) DO UPDATE SET
          name = @name, photo_path = @photoPath, web_photo = @webPhoto,
          box_id = @boxId, labels = @labels, updated_by = @accountId
      '''),
      parameters: {
        'id': item['id'],
        'name': item['name'],
        'photoPath': item['photoPath'],
        'webPhoto': item['webPhoto'] ?? false,
        'boxId': item['boxId'],
        'createdAt': DateTime.parse(item['createdAt'] as String),
        'labels': labels,
        'accountId': accountId,
      },
    );
  }

  Future<void> deleteItem(String id) async {
    await _db.execute(
      Sql.named('DELETE FROM items WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> clearAll() async {
    await _db.execute('DELETE FROM items');
    await _db.execute('DELETE FROM boxes');
  }
}

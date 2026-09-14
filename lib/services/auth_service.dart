import 'package:flutter/foundation.dart';

import '../models/account.dart';
import 'api_client.dart';

/// Session state and every account-related API call, in one place. UI code
/// listens to [currentAccount] rather than polling — it changes on sign-in,
/// sign-out, and setup.
class AuthService {
  static AuthService instance = AuthService._internal(ApiClient());
  AuthService._internal(this._api);
  AuthService.forTesting(ApiClient api) : _api = api;

  final ApiClient _api;

  final ValueNotifier<Account?> currentAccount = ValueNotifier(null);

  /// Whether the very first (root) account still needs to be created.
  Future<({bool needsSetup, bool signupsEnabled})> checkSetup() async {
    final json = await _api.get('/setup') as Map<String, dynamic>;
    return (
      needsSetup: json['needsSetup'] as bool,
      signupsEnabled: json['signupsEnabled'] as bool? ?? false,
    );
  }

  /// Creates the root account. Only succeeds once, ever.
  Future<Account> setup(String username, String password) async {
    final json = await _api.post('/setup', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    final account = Account.fromJson(json);
    currentAccount.value = account;
    return account;
  }

  Future<Account> signup(String username, String password) async {
    final json = await _api.post('/auth/signup', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    final account = Account.fromJson(json);
    currentAccount.value = account;
    return account;
  }

  Future<Account> login(String username, String password) async {
    final json = await _api.post('/auth/login', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    final account = Account.fromJson(json);
    currentAccount.value = account;
    return account;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      currentAccount.value = null;
    }
  }

  /// Checks whether the browser's session cookie is still valid, updating
  /// [currentAccount]. Returns the account, or null if not signed in.
  Future<Account?> refresh() async {
    try {
      final json = await _api.get('/auth/me') as Map<String, dynamic>;
      final account = Account.fromJson(json);
      currentAccount.value = account;
      return account;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        currentAccount.value = null;
        return null;
      }
      rethrow;
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post('/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // ── Root-only account management ───────────────────────────────────

  Future<List<Account>> listAccounts() async {
    final json = await _api.get('/accounts') as List<dynamic>;
    return json.map((m) => Account.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<Account> createAccount(String username, String password) async {
    final json = await _api.post('/accounts', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    return Account.fromJson(json);
  }

  Future<void> deleteAccount(String id) async {
    await _api.delete('/accounts/$id');
  }

  Future<void> resetPassword(String id, String newPassword) async {
    await _api.post('/accounts/$id/reset-password', {'password': newPassword});
  }

  Future<void> setSignupsEnabled(bool enabled) async {
    await _api.put('/settings/signups', {'enabled': enabled});
  }
}

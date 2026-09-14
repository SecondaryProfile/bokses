import 'dart:math';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

/// Password hashing and session-token helpers.
///
/// Passwords are hashed with Argon2id (OWASP's recommended settings: 19 MiB
/// memory, 2 iterations) with a random salt per password. Session tokens are
/// random 256-bit values; only their SHA-256 is ever stored, so a stolen
/// database can't be replayed as a session.
class Security {
  Security._();

  static final _random = Random.secure();

  // OWASP-recommended Argon2id settings: 19 MiB memory, 2 iterations.
  static const _security = Argon2Security(
    'bokses',
    m: 19 * 1024,
    p: 1,
    t: 2,
  );
  static const _argon2HashLength = 32;

  /// A fixed, valid-looking hash used to keep the timing of "unknown
  /// username" identical to "wrong password" — verifying against it always
  /// does the same expensive Argon2id work.
  static final String _dummyHash = hashPassword('not-a-real-password');

  static String get dummyHash => _dummyHash;

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Hashes [password] with a fresh random salt. The salt is embedded in the
  /// returned encoded string, so [verifyPassword] doesn't need it separately.
  static String hashPassword(String password) {
    final salt = _randomBytes(16);
    final digest = argon2id(
      password.codeUnits,
      salt,
      hashLength: _argon2HashLength,
      security: _security,
    );
    return digest.encoded();
  }

  /// Verifies [password] against a hash produced by [hashPassword]. Safe to
  /// call with [encodedHash] set to [dummyHash] when the account doesn't
  /// exist, to avoid leaking which usernames are registered via timing.
  static bool verifyPassword(String password, String encodedHash) {
    try {
      return argon2Verify(encodedHash, password.codeUnits);
    } catch (_) {
      return false;
    }
  }

  /// A random 256-bit session token, hex-encoded. The raw value goes in the
  /// cookie; only [hashToken] of it is ever persisted.
  static String generateToken() {
    return _randomBytes(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashToken(String token) => sha256.string(token).hex();
}

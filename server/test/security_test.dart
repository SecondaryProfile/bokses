import 'package:test/test.dart';

import 'package:bokses_server/src/security.dart';

void main() {
  group('password hashing', () {
    test('a password verifies against its own hash', () {
      final hash = Security.hashPassword('correct-horse');
      expect(Security.verifyPassword('correct-horse', hash), isTrue);
    });

    test('the wrong password fails verification', () {
      final hash = Security.hashPassword('correct-horse');
      expect(Security.verifyPassword('wrong-password', hash), isFalse);
    });

    test('hashing the same password twice yields different hashes (random salt)', () {
      expect(Security.hashPassword('correct-horse'), isNot(Security.hashPassword('correct-horse')));
    });

    test('dummyHash exists and never verifies against a real password', () {
      expect(Security.dummyHash, isNotEmpty);
      expect(Security.verifyPassword('anything', Security.dummyHash), isFalse);
    });

    test('verifyPassword returns false instead of throwing on a garbage hash', () {
      expect(Security.verifyPassword('x', 'not-a-real-encoded-hash'), isFalse);
    });
  });

  group('session tokens', () {
    test('generateToken produces distinct values', () {
      expect(Security.generateToken(), isNot(Security.generateToken()));
    });

    test('hashToken is deterministic', () {
      final token = Security.generateToken();
      expect(Security.hashToken(token), Security.hashToken(token));
    });

    test('hashToken differs for different tokens', () {
      expect(Security.hashToken(Security.generateToken()), isNot(Security.hashToken(Security.generateToken())));
    });
  });
}

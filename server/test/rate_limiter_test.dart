import 'package:test/test.dart';

import 'package:bokses_server/src/rate_limiter.dart';

void main() {
  test('a fresh key is not limited', () {
    final limiter = RateLimiter(maxAttempts: 3, window: const Duration(minutes: 1));
    expect(limiter.isLimited('ip:1.2.3.4'), isFalse);
  });

  test('is limited once maxAttempts failures are recorded', () {
    final limiter = RateLimiter(maxAttempts: 3, window: const Duration(minutes: 1));
    limiter.recordFailure('ip:1.2.3.4');
    limiter.recordFailure('ip:1.2.3.4');
    expect(limiter.isLimited('ip:1.2.3.4'), isFalse);
    limiter.recordFailure('ip:1.2.3.4');
    expect(limiter.isLimited('ip:1.2.3.4'), isTrue);
  });

  test('reset clears recorded failures', () {
    final limiter = RateLimiter(maxAttempts: 1, window: const Duration(minutes: 1));
    limiter.recordFailure('user:joe');
    expect(limiter.isLimited('user:joe'), isTrue);
    limiter.reset('user:joe');
    expect(limiter.isLimited('user:joe'), isFalse);
  });

  test('different keys are tracked independently', () {
    final limiter = RateLimiter(maxAttempts: 1, window: const Duration(minutes: 1));
    limiter.recordFailure('ip:1.2.3.4');
    expect(limiter.isLimited('ip:1.2.3.4'), isTrue);
    expect(limiter.isLimited('ip:5.6.7.8'), isFalse);
  });

  test('failures outside the window no longer count', () async {
    final limiter = RateLimiter(maxAttempts: 1, window: const Duration(milliseconds: 50));
    limiter.recordFailure('ip:1.2.3.4');
    expect(limiter.isLimited('ip:1.2.3.4'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(limiter.isLimited('ip:1.2.3.4'), isFalse);
  });
}

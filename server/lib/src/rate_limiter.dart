/// A small in-memory sliding-window limiter for sign-in attempts. Fine for a
/// single-instance, single-household app — no need for anything shared
/// across processes.
class RateLimiter {
  final int maxAttempts;
  final Duration window;
  final _attempts = <String, List<DateTime>>{};

  RateLimiter({this.maxAttempts = 10, this.window = const Duration(minutes: 15)});

  /// Returns true if [key] (an IP or a username) has hit the limit.
  bool isLimited(String key) {
    _prune(key);
    return (_attempts[key]?.length ?? 0) >= maxAttempts;
  }

  /// Records a failed attempt for [key].
  void recordFailure(String key) {
    _prune(key);
    _attempts.putIfAbsent(key, () => []).add(DateTime.now());
  }

  /// Clears attempts for [key], e.g. after a successful sign-in.
  void reset(String key) => _attempts.remove(key);

  void _prune(String key) {
    final cutoff = DateTime.now().subtract(window);
    _attempts[key]?.removeWhere((t) => t.isBefore(cutoff));
  }
}

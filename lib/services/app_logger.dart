import 'dart:async';

/// Captures console output (print/debugPrint from anywhere in the app or its
/// plugins) and uncaught errors into a rolling in-memory buffer, so a user can
/// export it for troubleshooting instead of having to open the browser console.
///
/// The buffer lives for the lifetime of the tab — a reload starts a fresh log.
class AppLogger {
  static const _maxLines = 5000;
  static final List<String> _lines = <String>[];

  /// Logs a raw console line as-is (used to mirror print/debugPrint output).
  static void appendRaw(String line) => _append(line);

  static void log(String tag, String message) {
    _append('[${DateTime.now().toIso8601String()}] [$tag] $message');
  }

  static void logError(String tag, String message, [StackTrace? stack]) {
    final buf = StringBuffer(
        '[${DateTime.now().toIso8601String()}] [$tag] ERROR: $message');
    if (stack != null) buf.write('\n$stack');
    _append(buf.toString());
  }

  static void _append(String line) {
    _lines.add(line);
    if (_lines.length > _maxLines) {
      _lines.removeRange(0, _lines.length - _maxLines ~/ 2);
    }
  }

  /// Kept so callers can await the log without caring whether writes are async.
  static Future<void> flush() => Future.value();

  static Future<String> readLog() async => _lines.join('\n');

  static Future<void> clear() async => _lines.clear();
}

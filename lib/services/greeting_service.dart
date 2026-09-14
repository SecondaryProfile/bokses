import 'dart:math';
import 'package:http/http.dart' as http;

/// Random "Hi, {name}!"-style sidebar greetings. Templates come from
/// greetings.csv, served as a static file alongside the app — gitignored so
/// each instance can customize its own wording without touching source
/// control. Falls back to a small built-in set when that file hasn't been
/// added (a fresh checkout) or is unreachable.
class GreetingService {
  static const _fallbackTemplates = [
    'Hi, {name}!',
    'Welcome, {name}!',
    'Hey, {name}!',
  ];

  static final _random = Random();

  static Future<String> greetingFor(String name) async {
    final templates = await _loadTemplates();
    final template = templates[_random.nextInt(templates.length)];
    return template.replaceAll('{name}', name);
  }

  static Future<List<String>> _loadTemplates() async {
    try {
      final res = await http
          .get(Uri.base.resolve('greetings.csv'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return _fallbackTemplates;
      final lines = res.body.split('\n').map((l) => l.trim()).where((l) =>
          l.isNotEmpty &&
          !l.startsWith('<') && // nginx's SPA fallback serves index.html
          l.toLowerCase() != 'greeting' // header row, if present
          ).toList();
      return lines.isEmpty ? _fallbackTemplates : lines;
    } catch (_) {
      return _fallbackTemplates;
    }
  }
}

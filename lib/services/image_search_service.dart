import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageSearchResult {
  final String thumbnailUrl;
  final String imageUrl;
  final String title;

  const ImageSearchResult({
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.title,
  });
}

/// Thrown when DuckDuckGo itself rejects the request (HTTP 403/429) — this
/// isn't a Bokses bug, it's their anti-bot/rate-limit protection on the
/// unofficial endpoint this service scrapes. Once it starts happening, more
/// requests in quick succession just make it worse, so callers doing several
/// searches in a row (e.g. bulk auto-fill) should stop instead of retrying.
class ImageSearchBlockedException implements Exception {
  final int statusCode;
  const ImageSearchBlockedException(this.statusCode);
  @override
  String toString() =>
      'DuckDuckGo is rate-limiting image search requests (HTTP $statusCode). Try again in a few minutes.';
}

class ImageSearchService {
  // Realistic mobile browser headers — DDG blocks obvious bot requests.
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static void _checkBlocked(http.Response res) {
    if (res.statusCode == 403 || res.statusCode == 429) {
      throw ImageSearchBlockedException(res.statusCode);
    }
  }

  static Future<List<ImageSearchResult>> search(String query) async {
    // ── Step 1: load the DDG images page to get the session token (vqd) ──────
    final initRes = await http
        .get(
          Uri.parse(
            'https://duckduckgo.com/'
            '?q=${Uri.encodeComponent(query)}&iax=images&ia=images',
          ),
          headers: {..._headers, 'Accept': 'text/html'},
        )
        .timeout(const Duration(seconds: 12));
    _checkBlocked(initRes);

    final vqd = _extractVqd(initRes.body);
    if (vqd == null) {
      throw Exception('Image search unavailable — could not get session token.');
    }

    // A short gap between the two DuckDuckGo requests, instead of firing
    // them back-to-back — bursty request pairs are exactly what trips their
    // rate limiting the fastest.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // ── Step 2: call the JSON image API ──────────────────────────────────────
    final searchRes = await http
        .get(
          Uri.parse(
            'https://duckduckgo.com/i.js'
            '?q=${Uri.encodeComponent(query)}'
            '&o=json&p=1'
            '&vqd=${Uri.encodeComponent(vqd)}'
            '&f=,,,,,&l=us-en',
          ),
          headers: {
            ..._headers,
            'Accept': 'application/json',
            'Referer': 'https://duckduckgo.com/',
          },
        )
        .timeout(const Duration(seconds: 12));
    _checkBlocked(searchRes);

    if (searchRes.statusCode != 200) {
      throw Exception('Image search failed (HTTP ${searchRes.statusCode}).');
    }

    final body = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final raw = (body['results'] as List<dynamic>?) ?? [];

    return raw
        .map((r) {
          final m = r as Map<String, dynamic>;
          return ImageSearchResult(
            thumbnailUrl: (m['thumbnail'] as String?)?.trim() ?? '',
            imageUrl: (m['image'] as String?)?.trim() ?? '',
            title: (m['title'] as String?)?.trim() ?? query,
          );
        })
        .where((r) => r.thumbnailUrl.isNotEmpty)
        .take(10)
        .toList();
  }

  /// Downloads the thumbnail and returns a `data:<mime>;base64,...` URI.
  /// Thumbnails are 200–400 px — right-sized for item photos in SharedPreferences.
  static Future<String> downloadAsDataUri(String url) async {
    final res = await http
        .get(
          Uri.parse(url),
          headers: {
            ..._headers,
            'Accept': 'image/*',
            'Referer': 'https://duckduckgo.com/',
          },
        )
        .timeout(const Duration(seconds: 15));
    _checkBlocked(res);

    if (res.statusCode != 200) {
      throw Exception('Image download failed (HTTP ${res.statusCode}).');
    }

    final mime = _inferMime(url, res.headers['content-type']);
    return 'data:$mime;base64,${base64Encode(res.bodyBytes)}';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  // DDG has used several formats for the vqd token over the years.
  static String? _extractVqd(String html) {
    for (final pattern in [
      RegExp(r"vqd='([^']+)'"),
      RegExp(r'vqd="([^"]+)"'),
      RegExp(r'vqd=([\d-]+)'),
      RegExp(r'"vqd"\s*:\s*"([^"]+)"'),
    ]) {
      final m = pattern.firstMatch(html);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String _inferMime(String url, String? contentType) {
    if (contentType != null) {
      if (contentType.contains('png')) return 'image/png';
      if (contentType.contains('webp')) return 'image/webp';
      if (contentType.contains('gif')) return 'image/gif';
    }
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.webp')) return 'image/webp';
    if (lower.contains('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

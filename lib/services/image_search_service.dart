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

class ImageSearchService {
  // Realistic mobile browser headers — DDG blocks obvious bot requests.
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

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

    final vqd = _extractVqd(initRes.body);
    if (vqd == null) {
      throw Exception('Image search unavailable — could not get session token.');
    }

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

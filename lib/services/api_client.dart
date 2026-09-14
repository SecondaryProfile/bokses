import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response. [statusCode] lets callers special-case
/// 401 (not signed in) and 403 (signed in, but not allowed) without string
/// matching on [message].
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Talks to the Bokses API server at `/api`. Requests are same-origin (nginx
/// proxies /api/ to the Dart server), so the browser attaches the session
/// cookie automatically — nothing special to configure here.
class ApiClient {
  static const _base = '/api';
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_base$path').replace(queryParameters: query);

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) message = body['error'] as String;
      } catch (_) {
        // Non-JSON error body (e.g. a proxy error page) — keep the default.
      }
      throw ApiException(response.statusCode, message);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query));
    return _decode(response);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      _uri(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _client.put(
      _uri(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(_uri(path));
    return _decode(response);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sensor_config.dart';

class FirebaseDatabaseException implements Exception {
  final String message;

  const FirebaseDatabaseException(this.message);

  @override
  String toString() => message;
}

class FirebaseDatabaseService {
  FirebaseDatabaseService._();

  static final FirebaseDatabaseService instance = FirebaseDatabaseService._();

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  Future<dynamic> get(String path) async {
    return _send('GET', path);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    return _send('POST', path, body: body);
  }

  Future<dynamic> delete(String path) async {
    return _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = await _client.openUrl(
        method,
        Uri.parse(SensorConfig.firebaseUrlFor(path)),
      );
      request.headers.contentType = ContentType.json;

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FirebaseDatabaseException(
          'Firebase request failed (${response.statusCode}): $responseBody',
        );
      }

      if (responseBody.trim().isEmpty || responseBody == 'null') {
        return null;
      }

      return jsonDecode(responseBody);
    } on TimeoutException {
      throw const FirebaseDatabaseException(
        'Unable to reach Firebase right now. Check your internet connection and verify the database URL in sensor_config.dart.',
      );
    } on SocketException {
      throw const FirebaseDatabaseException(
        'Unable to connect to Firebase. Check your internet connection and try again.',
      );
    }
  }
}

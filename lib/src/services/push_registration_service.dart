import 'dart:convert';
import 'dart:io';

import '../auth/auth_session_controller.dart';

/// Platform-neutral push registration contract.
///
/// Firebase Messaging supplies the token externally after Firebase is connected.
/// This class keeps token delivery, rotation and revocation ready without coupling
/// the application core to a specific notification vendor.
class PushRegistrationService {
  PushRegistrationService(this.controller, {HttpClient? client})
      : _client = client ?? HttpClient();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final AuthSessionController controller;
  final HttpClient _client;

  Future<void> register({
    required String token,
    required String platform,
    String? locale,
    String? timezone,
  }) async {
    await _send(
      'POST',
      '/v1/me/push-devices',
      body: {
        'token': token,
        'platform': platform,
        if (locale != null) 'locale': locale,
        if (timezone != null) 'timezone': timezone,
      },
    );
  }

  Future<void> unregister(String token) async {
    await _send(
      'DELETE',
      '/v1/me/push-devices',
      body: {'token': token},
    );
  }

  Future<void> _send(
    String method,
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final token = controller.session?.accessToken;
    if (token == null) return;
    final request = await _client
        .openUrl(method, Uri.parse('$_baseUrl$path'))
        .timeout(const Duration(seconds: 10));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 10));
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Push registration failed: ${response.statusCode}');
    }
  }
}

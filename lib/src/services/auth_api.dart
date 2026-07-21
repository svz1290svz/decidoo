import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.preferredLanguage,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;
  final String role;
  final String preferredLanguage;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: (json['email'] as String?) ?? '',
        displayName: json['displayName'] as String?,
        role: (json['role'] as String?) ?? 'USER',
        preferredLanguage: (json['preferredLanguage'] as String?) ?? 'tr',
      );
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class AuthApiException implements Exception {
  const AuthApiException(this.code, [this.statusCode]);

  final String code;
  final int? statusCode;

  @override
  String toString() => code;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$_configuredBaseUrl$path');

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLanguage,
  }) async {
    final response = await _post(
      '/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'preferredLanguage': preferredLanguage,
      },
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response);
  }

  Future<void> requestPasswordReset(String email) async {
    await _post(
      '/v1/auth/password-reset/request',
      body: {'email': email},
      allowEmpty: true,
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _post(
      '/v1/auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return AuthSession.fromJson(response);
  }

  Future<void> logout(String refreshToken) async {
    await _post(
      '/v1/auth/logout',
      body: {'refreshToken': refreshToken},
      allowEmpty: true,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    bool allowEmpty = false,
  }) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (allowEmpty || response.body.isEmpty) return const {};
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      String code = 'REQUEST_FAILED';
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is String) {
          code = decoded['error'] as String;
        }
      }
      throw AuthApiException(code, response.statusCode);
    } on AuthApiException {
      rethrow;
    } catch (_) {
      throw const AuthApiException('SERVICE_UNAVAILABLE');
    }
  }
}

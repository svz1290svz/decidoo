import 'dart:convert';
import 'dart:io';

import '../auth/auth_session_controller.dart';

class AppApiException implements Exception {
  const AppApiException(this.code);
  final String code;
}

class AppApi {
  AppApi(this.controller, {HttpClient? client}) : _client = client ?? HttpClient();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final AuthSessionController controller;
  final HttpClient _client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = controller.session?.accessToken;
    if (token == null) throw const AppApiException('AUTH_REQUIRED');

    final request = await _client.openUrl(method, Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    final payload = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppApiException((payload['error'] ?? 'REQUEST_FAILED').toString());
    }
    return payload;
  }

  Future<List<Map<String, dynamic>>> restaurants({String? query}) async {
    final suffix = query == null || query.trim().isEmpty
        ? ''
        : '?q=${Uri.encodeQueryComponent(query.trim())}';
    final data = await _request('GET', '/v1/restaurants$suffix');
    return (data['restaurants'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> recommendations({
    double? maxBudget,
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
  }) async {
    final data = await _request('POST', '/v1/recommendations', body: {
      if (maxBudget != null) 'maxBudget': maxBudget,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm,
      'limit': 10,
    });
    return (data['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final data = await _request('GET', '/v1/favorites');
    return (data['favorites'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> addFavorite({String? restaurantId, String? mealId}) async {
    await _request('POST', '/v1/favorites', body: {
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (mealId != null) 'mealId': mealId,
    });
  }

  Future<void> removeFavorite(String id) async {
    await _request('DELETE', '/v1/favorites/$id');
  }

  Future<void> updateProfile({
    required String displayName,
    required String preferredLanguage,
  }) async {
    await _request('PATCH', '/v1/me', body: {
      'displayName': displayName,
      'preferredLanguage': preferredLanguage,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request('POST', '/v1/me/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<Map<String, dynamic>>> ownerRestaurants() async {
    final data = await _request('GET', '/v1/owner/restaurants');
    return (data['restaurants'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> createRestaurant({
    required String name,
    required String addressLine,
    required String city,
    required double latitude,
    required double longitude,
  }) async {
    await _request('POST', '/v1/owner/restaurants', body: {
      'name': name,
      'addressLine': addressLine,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> submitRestaurant(String id) async {
    await _request('PATCH', '/v1/owner/restaurants/$id', body: {
      'status': 'PENDING_APPROVAL',
    });
  }

  Future<List<Map<String, dynamic>>> adminRestaurants({
    String status = 'PENDING_APPROVAL',
  }) async {
    final data = await _request(
      'GET',
      '/v1/admin/restaurants?status=${Uri.encodeQueryComponent(status)}',
    );
    return (data['restaurants'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> moderateRestaurant({
    required String id,
    required String status,
  }) async {
    await _request('PATCH', '/v1/admin/restaurants/$id/moderate', body: {
      'status': status,
    });
  }
}

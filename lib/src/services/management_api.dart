import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../auth/auth_session_controller.dart';
import 'app_api.dart';

class ManagementApi {
  ManagementApi(this.controller, {HttpClient? client})
      : _client = client ?? HttpClient();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const _timeout = Duration(seconds: 15);

  final AuthSessionController controller;
  final HttpClient _client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = controller.session?.accessToken;
    if (token == null) throw const AppApiException('AUTH_REQUIRED');
    try {
      final request = await _client
          .openUrl(method, Uri.parse('$_baseUrl$path'))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(_timeout);
      final raw = await response.transform(utf8.decoder).join().timeout(_timeout);
      final data = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppApiException(
          (data['error'] ?? 'REQUEST_FAILED').toString(),
          statusCode: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const AppApiException('REQUEST_TIMEOUT');
    } on SocketException {
      throw const AppApiException('SERVICE_UNAVAILABLE');
    }
  }

  Future<Map<String, dynamic>> adminDashboard() =>
      _request('GET', '/v1/admin/dashboard');

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

  Future<void> moderateRestaurant(String id, String status) async {
    await _request(
      'PATCH',
      '/v1/admin/restaurants/$id/moderate',
      body: {'status': status},
    );
  }

  Future<List<Map<String, dynamic>>> ownerRestaurants() async {
    final data = await _request('GET', '/v1/owner/restaurants');
    return (data['restaurants'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> updateOperatingHours({
    required String restaurantId,
    required List<Map<String, dynamic>> hours,
  }) async {
    final data = await _request(
      'PUT',
      '/v1/owner/restaurants/$restaurantId/operating-hours',
      body: {'hours': hours},
    );
    return (data['hours'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> createCategory({
    required String restaurantId,
    required String name,
    int sortOrder = 0,
  }) async {
    await _request(
      'POST',
      '/v1/owner/restaurants/$restaurantId/categories',
      body: {'name': name, 'sortOrder': sortOrder},
    );
  }

  Future<void> createMeal({
    required String restaurantId,
    String? categoryId,
    required String name,
    required double price,
    required String currency,
    String? description,
    String? imageUrl,
    String? cuisine,
    String? mealType,
  }) async {
    await _request(
      'POST',
      '/v1/owner/restaurants/$restaurantId/meals',
      body: {
        if (categoryId != null) 'categoryId': categoryId,
        'name': name,
        'price': price,
        'currency': currency,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine,
        if (mealType != null && mealType.isNotEmpty) 'mealType': mealType,
        'ingredients': <String>[],
        'allergens': <String>[],
        'tags': <String>[],
      },
    );
  }

  Future<void> updateMeal({
    required String mealId,
    double? price,
    bool? isAvailable,
    String? imageUrl,
  }) async {
    await _request(
      'PATCH',
      '/v1/owner/meals/$mealId',
      body: {
        if (price != null) 'price': price,
        if (isAvailable != null) 'isAvailable': isAvailable,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
  }

  void close() => _client.close(force: true);
}

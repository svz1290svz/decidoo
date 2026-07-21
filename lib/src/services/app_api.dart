import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../auth/auth_session_controller.dart';
import 'offline_cache.dart';

class AppApiException implements Exception {
  const AppApiException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => code;
}

class AppApi {
  AppApi(
    this.controller, {
    HttpClient? client,
    OfflineCache? cache,
  })  : _client = client ?? HttpClient(),
        _cache = cache ?? OfflineCache();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const _requestTimeout = Duration(seconds: 15);

  final AuthSessionController controller;
  final HttpClient _client;
  final OfflineCache _cache;

  String _cacheKey(String key) => '${controller.session?.user.id ?? 'anonymous'}_$key';

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final maxTransportAttempts = method == 'GET' ? 2 : 1;
    var authRefreshAttempted = false;
    Object? lastError;

    for (var attempt = 1; attempt <= maxTransportAttempts; attempt++) {
      final token = controller.session?.accessToken;
      if (token == null) throw const AppApiException('AUTH_REQUIRED');

      try {
        final request = await _client
            .openUrl(method, Uri.parse('$baseUrl$path'))
            .timeout(_requestTimeout);
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
        request.headers.set('x-client-platform', Platform.operatingSystem);
        if (body != null) request.write(jsonEncode(body));

        final response = await request.close().timeout(_requestTimeout);
        final raw = await response
            .transform(utf8.decoder)
            .join()
            .timeout(_requestTimeout);
        final payload = _decodePayload(raw);

        if (response.statusCode == HttpStatus.unauthorized &&
            !authRefreshAttempted) {
          authRefreshAttempted = true;
          final refreshed = await controller.refreshSession();
          if (refreshed) {
            attempt -= 1;
            continue;
          }
          throw const AppApiException(
            'AUTH_REQUIRED',
            statusCode: HttpStatus.unauthorized,
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw AppApiException(
            (payload['error'] ?? 'REQUEST_FAILED').toString(),
            statusCode: response.statusCode,
          );
        }
        return payload;
      } on AppApiException {
        rethrow;
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on HttpException catch (error) {
        lastError = error;
      } on FormatException {
        throw const AppApiException('INVALID_SERVER_RESPONSE');
      }

      if (attempt < maxTransportAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    if (lastError is TimeoutException) {
      throw const AppApiException('REQUEST_TIMEOUT');
    }
    throw const AppApiException('SERVICE_UNAVAILABLE');
  }

  Future<Map<String, dynamic>> _cachedRequest(
    String cacheKey,
    Future<Map<String, dynamic>> Function() loader, {
    Duration ttl = const Duration(hours: 6),
  }) async {
    try {
      final value = await loader();
      await _cache.write(_cacheKey(cacheKey), value, ttl: ttl);
      return value;
    } on AppApiException catch (error) {
      if (error.code != 'SERVICE_UNAVAILABLE' &&
          error.code != 'REQUEST_TIMEOUT') {
        rethrow;
      }
      final cached = await _cache.read(
        _cacheKey(cacheKey),
        allowExpired: true,
      );
      if (cached != null) return {...cached, '_offline': true};
      rethrow;
    }
  }

  Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> restaurants({String? query}) async {
    final suffix = query == null || query.trim().isEmpty
        ? ''
        : '?q=${Uri.encodeQueryComponent(query.trim())}';
    final data = await _cachedRequest(
      'restaurants_$suffix',
      () => _request('GET', '/v1/restaurants$suffix'),
      ttl: const Duration(hours: 12),
    );
    return (data['restaurants'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> recommendations({
    double? maxBudget,
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    String? cuisine,
    String? mealType,
    String? mood,
    int? hungerLevel,
  }) async {
    final requestBody = <String, dynamic>{
      if (maxBudget != null) 'maxBudget': maxBudget,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm,
      if (cuisine != null && cuisine.trim().isNotEmpty) 'cuisine': cuisine.trim(),
      if (mealType != null && mealType.trim().isNotEmpty)
        'mealType': mealType.trim(),
      if (mood != null && mood.trim().isNotEmpty) 'mood': mood.trim(),
      if (hungerLevel != null) 'hungerLevel': hungerLevel,
      'limit': 10,
    };
    final cacheKey = 'recommendations_${base64Url.encode(utf8.encode(jsonEncode(requestBody)))}';
    final data = await _cachedRequest(
      cacheKey,
      () => _request('POST', '/v1/recommendations', body: requestBody),
      ttl: const Duration(hours: 2),
    );
    return (data['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final data = await _cachedRequest(
      'favorites',
      () => _request('GET', '/v1/favorites'),
    );
    return (data['favorites'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> addFavorite({String? restaurantId, String? mealId}) async {
    await _request('POST', '/v1/favorites', body: {
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (mealId != null) 'mealId': mealId,
    });
    await _cache.delete(_cacheKey('favorites'));
  }

  Future<void> removeFavorite(String id) async {
    await _request('DELETE', '/v1/favorites/$id');
    await _cache.delete(_cacheKey('favorites'));
  }

  Future<Map<String, dynamic>?> preferences() async {
    final data = await _cachedRequest(
      'preferences',
      () => _request('GET', '/v1/me/preferences'),
    );
    return data['preference'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> preferences,
  ) async {
    final data = await _request(
      'PUT',
      '/v1/me/preferences',
      body: preferences,
    );
    await _cache.write(_cacheKey('preferences'), data);
    return (data['preference'] as Map<String, dynamic>?) ?? const {};
  }

  Future<List<Map<String, dynamic>>> recentSearches() async {
    final data = await _cachedRequest(
      'recent_searches',
      () => _request('GET', '/v1/me/recent-searches'),
      ttl: const Duration(hours: 24),
    );
    return (data['searches'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> clearRecentSearches() async {
    await _request('DELETE', '/v1/me/recent-searches');
    await _cache.delete(_cacheKey('recent_searches'));
  }

  Future<Map<String, dynamic>> personalizationSummary() =>
      _request('GET', '/v1/me/personalization-summary');

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../auth/auth_session_controller.dart';
import 'app_api.dart';
import 'offline_sync_queue.dart';

class SyncResult {
  const SyncResult({required this.synced, required this.pending, required this.conflicts});
  final int synced;
  final int pending;
  final int conflicts;
}

class StoreReadyApi {
  StoreReadyApi(
    this.controller, {
    AppApi? appApi,
    OfflineSyncQueue? queue,
    HttpClient? client,
  })  : appApi = appApi ?? AppApi(controller),
        queue = queue ?? OfflineSyncQueue(),
        _client = client ?? HttpClient();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const _timeout = Duration(seconds: 15);

  final AuthSessionController controller;
  final AppApi appApi;
  final OfflineSyncQueue queue;
  final HttpClient _client;

  bool _isOfflineError(Object error) => error is AppApiException &&
      (error.code == 'SERVICE_UNAVAILABLE' || error.code == 'REQUEST_TIMEOUT');

  Future<void> addFavorite({String? restaurantId, String? mealId}) async {
    final payload = <String, dynamic>{
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (mealId != null) 'mealId': mealId,
    };
    try {
      await appApi.addFavorite(restaurantId: restaurantId, mealId: mealId);
    } catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await queue.enqueue('favorite.add', payload);
    }
  }

  Future<void> removeFavorite(String favoriteId) async {
    try {
      await appApi.removeFavorite(favoriteId);
    } catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await queue.enqueue('favorite.remove', {'favoriteId': favoriteId});
    }
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> preferences, {
    DateTime? baseUpdatedAt,
  }) async {
    try {
      return await appApi.updatePreferences(preferences);
    } catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await queue.enqueue(
        'preferences.update',
        preferences,
        baseUpdatedAt: baseUpdatedAt,
      );
      return {...preferences, '_pendingSync': true};
    }
  }

  Future<SyncResult> syncPending() async {
    if (!controller.isAuthenticated) {
      final pending = await queue.readAll();
      return SyncResult(synced: 0, pending: pending.length, conflicts: 0);
    }

    final pending = await queue.readAll();
    final remaining = <OfflineMutation>[];
    var synced = 0;
    var conflicts = 0;

    for (final mutation in pending) {
      try {
        switch (mutation.type) {
          case 'favorite.add':
            await appApi.addFavorite(
              restaurantId: mutation.payload['restaurantId']?.toString(),
              mealId: mutation.payload['mealId']?.toString(),
            );
          case 'favorite.remove':
            await appApi.removeFavorite(mutation.payload['favoriteId'].toString());
          case 'preferences.update':
            final server = await appApi.preferences();
            final serverUpdatedAt = DateTime.tryParse(
              server?['updatedAt']?.toString() ?? '',
            );
            if (mutation.baseUpdatedAt != null &&
                serverUpdatedAt != null &&
                serverUpdatedAt.isAfter(mutation.baseUpdatedAt!)) {
              conflicts += 1;
              // Explicit last-write-wins policy: queued user edit wins.
            }
            await appApi.updatePreferences(mutation.payload);
          default:
            continue;
        }
        synced += 1;
      } catch (error) {
        if (_isOfflineError(error) && mutation.attempts < 10) {
          remaining.add(mutation.incrementAttempt());
        } else if (error is AppApiException && error.statusCode == 409) {
          conflicts += 1;
        }
      }
    }

    await queue.replace(remaining);
    return SyncResult(
      synced: synced,
      pending: remaining.length,
      conflicts: conflicts,
    );
  }

  Future<Map<String, dynamic>> restaurantDetail(String slug) async {
    final token = controller.session?.accessToken;
    if (token == null) throw const AppApiException('AUTH_REQUIRED');
    try {
      final request = await _client
          .getUrl(Uri.parse('$_baseUrl/v1/restaurants/${Uri.encodeComponent(slug)}'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final response = await request.close().timeout(_timeout);
      final raw = await response.transform(utf8.decoder).join().timeout(_timeout);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppApiException(
          (data['error'] ?? 'REQUEST_FAILED').toString(),
          statusCode: response.statusCode,
        );
      }
      return (data['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {};
    } on TimeoutException {
      throw const AppApiException('REQUEST_TIMEOUT');
    } on SocketException {
      throw const AppApiException('SERVICE_UNAVAILABLE');
    }
  }

  void close() => _client.close(force: true);
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineCache {
  OfflineCache({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'decidoo_cache_v1_';
  final FlutterSecureStorage _storage;

  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(hours: 6),
  }) async {
    final envelope = <String, dynamic>{
      'expiresAt': DateTime.now().add(ttl).toUtc().toIso8601String(),
      'value': value,
    };
    await _storage.write(key: '$_prefix$key', value: jsonEncode(envelope));
  }

  Future<Map<String, dynamic>?> read(
    String key, {
    bool allowExpired = false,
  }) async {
    final raw = await _storage.read(key: '$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final expiresAt = DateTime.tryParse(decoded['expiresAt']?.toString() ?? '');
      if (!allowExpired &&
          (expiresAt == null || expiresAt.isBefore(DateTime.now().toUtc()))) {
        await delete(key);
        return null;
      }
      final value = decoded['value'];
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      await delete(key);
      return null;
    }
  }

  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');

  Future<void> clearKnownCaches() => Future.wait([
        delete('restaurants'),
        delete('favorites'),
        delete('recommendations'),
        delete('preferences'),
        delete('recent_searches'),
      ]);
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineMutation {
  const OfflineMutation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.baseUpdatedAt,
    this.attempts = 0,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? baseUpdatedAt;
  final int attempts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        if (baseUpdatedAt != null) 'baseUpdatedAt': baseUpdatedAt!.toIso8601String(),
        'attempts': attempts,
      };

  factory OfflineMutation.fromJson(Map<String, dynamic> json) => OfflineMutation(
        id: json['id'].toString(),
        type: json['type'].toString(),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(json['createdAt'].toString()),
        baseUpdatedAt: json['baseUpdatedAt'] == null
            ? null
            : DateTime.tryParse(json['baseUpdatedAt'].toString()),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );

  OfflineMutation incrementAttempt() => OfflineMutation(
        id: id,
        type: type,
        payload: payload,
        createdAt: createdAt,
        baseUpdatedAt: baseUpdatedAt,
        attempts: attempts + 1,
      );
}

class OfflineSyncQueue {
  OfflineSyncQueue({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'decidoo_pending_mutations_v1';
  final FlutterSecureStorage _storage;

  Future<List<OfflineMutation>> readAll() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => OfflineMutation.fromJson(
                (item as Map).cast<String, dynamic>(),
              ))
          .toList();
    } catch (_) {
      await clear();
      return [];
    }
  }

  Future<void> enqueue(
    String type,
    Map<String, dynamic> payload, {
    DateTime? baseUpdatedAt,
  }) async {
    final items = await readAll();
    final mutation = OfflineMutation(
      id: '${DateTime.now().microsecondsSinceEpoch}-$type',
      type: type,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      baseUpdatedAt: baseUpdatedAt?.toUtc(),
    );

    // Last write wins for profile/preferences. Favorites remain independent.
    if (type == 'preferences.update') {
      items.removeWhere((item) => item.type == type);
    }
    items.add(mutation);
    await _write(items.take(100).toList());
  }

  Future<void> replace(List<OfflineMutation> items) => _write(items);

  Future<void> clear() => _storage.delete(key: _storageKey);

  Future<void> _write(List<OfflineMutation> items) => _storage.write(
        key: _storageKey,
        value: jsonEncode(items.map((item) => item.toJson()).toList()),
      );
}

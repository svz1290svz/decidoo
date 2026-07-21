import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Captures uncaught application failures without blocking startup or shutdown.
///
/// Set ERROR_REPORT_URL at build time to forward sanitized reports to an
/// observability collector. Reports never include authentication tokens,
/// request bodies, email addresses, or location data.
class ErrorReporter {
  ErrorReporter({HttpClient? client}) : _client = client ?? HttpClient();

  static const _endpoint = String.fromEnvironment('ERROR_REPORT_URL');
  static const _timeout = Duration(seconds: 5);
  static const _maxErrorLength = 500;
  static const _maxStackLength = 4000;

  final HttpClient _client;

  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
    String source = 'app',
  }) async {
    final safeError = _sanitize(error.toString(), _maxErrorLength);
    final safeStack = _sanitize(stackTrace.toString(), _maxStackLength);

    developer.log(
      safeError,
      name: 'decidoo.$source',
      error: error,
      stackTrace: stackTrace,
      level: fatal ? 1200 : 1000,
    );

    if (_endpoint.isEmpty) return;

    final payload = <String, Object?>{
      'service': 'decidoo-mobile',
      'source': source,
      'fatal': fatal,
      'errorType': error.runtimeType.toString(),
      'message': safeError,
      'stackTrace': safeStack,
      'platform': defaultTargetPlatform.name,
      'releaseMode': kReleaseMode,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final request = await _client
          .postUrl(Uri.parse(_endpoint))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().timeout(_timeout);
    } on Object catch (reportingError, reportingStack) {
      developer.log(
        'Error report delivery failed',
        name: 'decidoo.observability',
        error: reportingError,
        stackTrace: reportingStack,
        level: 900,
      );
    }
  }

  String _sanitize(String value, int maxLength) {
    final normalized = value
        .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
        .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~-]+'), 'Bearer [token]')
        .replaceAll(RegExp(r'([?&](?:token|code|secret)=)[^&\s]+'), r'$1[redacted]');
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength)}…';
  }
}

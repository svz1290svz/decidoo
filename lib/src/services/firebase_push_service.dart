import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session_controller.dart';

@pragma('vm:entry-point')
Future<void> decidooFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Native Firebase configuration is an external deployment input.
  }
}

class FirebasePushService {
  FirebasePushService(this.controller, {HttpClient? client})
      : _client = client ?? HttpClient();

  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final AuthSessionController controller;
  final HttpClient _client;
  final ValueNotifier<RemoteMessage?> foregroundMessage = ValueNotifier(null);

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _firebaseAvailable = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      FirebaseMessaging.onBackgroundMessage(decidooFirebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        foregroundMessage.value = message;
      });
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(registerToken(token));
      });

      controller.addListener(_onSessionChanged);
      await syncCurrentToken();
    } catch (_) {
      _firebaseAvailable = false;
    }
  }

  void _onSessionChanged() {
    if (controller.isAuthenticated) {
      unawaited(syncCurrentToken());
    }
  }

  Future<void> syncCurrentToken() async {
    if (!_firebaseAvailable || !controller.isAuthenticated) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) await registerToken(token);
  }

  Future<void> registerToken(String token) async {
    if (token == _lastRegisteredToken || !controller.isAuthenticated) return;
    final accessToken = controller.session?.accessToken;
    if (accessToken == null) return;

    try {
      final request = await _client.postUrl(
        Uri.parse('$_apiBaseUrl/v1/me/push-devices'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      request.write(jsonEncode({
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : Platform.isIOS
                ? 'ios'
                : 'android',
        'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        'timezone': DateTime.now().timeZoneName,
      }));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastRegisteredToken = token;
      }
    } catch (_) {
      // A later session or FCM token refresh retries registration.
    }
  }

  Future<void> dispose() async {
    controller.removeListener(_onSessionChanged);
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
    foregroundMessage.dispose();
    _client.close(force: true);
  }
}

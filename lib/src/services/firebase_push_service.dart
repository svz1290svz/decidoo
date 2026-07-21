import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  void dismissForegroundMessage() {
    foregroundMessage.value = null;
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

class PushNotificationHost extends StatefulWidget {
  const PushNotificationHost({
    super.key,
    required this.service,
    required this.child,
  });

  final FirebasePushService service;
  final Widget child;

  @override
  State<PushNotificationHost> createState() => _PushNotificationHostState();
}

class _PushNotificationHostState extends State<PushNotificationHost> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    widget.service.foregroundMessage.addListener(_scheduleDismiss);
  }

  void _scheduleDismiss() {
    _dismissTimer?.cancel();
    if (widget.service.foregroundMessage.value != null) {
      _dismissTimer = Timer(const Duration(seconds: 6), () {
        widget.service.dismissForegroundMessage();
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    widget.service.foregroundMessage.removeListener(_scheduleDismiss);
    unawaited(widget.service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          ValueListenableBuilder<RemoteMessage?>(
            valueListenable: widget.service.foregroundMessage,
            builder: (context, message, _) {
              if (message == null) return const SizedBox.shrink();
              final title = message.notification?.title ??
                  message.data['title']?.toString() ??
                  'Decidoo';
              final body = message.notification?.body ??
                  message.data['body']?.toString() ??
                  '';
              return Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 12,
                  color: const Color(0xFF171B31),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF6B35),
                      child: Icon(Icons.notifications_active, color: Colors.white),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: body.isEmpty ? null : Text(body),
                    trailing: IconButton(
                      onPressed: widget.service.dismissForegroundMessage,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

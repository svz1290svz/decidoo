import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_api.dart';

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({AuthApi? api, FlutterSecureStorage? storage})
      : _api = api ?? AuthApi(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'decidoo_access_token';
  static const _refreshTokenKey = 'decidoo_refresh_token';

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  AuthSession? _session;
  bool _loading = true;
  String? _errorCode;
  Future<bool>? _refreshInFlight;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isLoading => _loading;
  String? get errorCode => _errorCode;

  Future<void> restore() async {
    _loading = true;
    _errorCode = null;
    notifyListeners();

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _session = await _api.refresh(refreshToken);
      await _persist(_session!);
    } on AuthApiException catch (error) {
      _errorCode = error.code;
      _session = null;
      if (_isTerminalAuthError(error)) {
        await _clearStoredTokens();
      }
    } catch (_) {
      _errorCode = 'SERVICE_UNAVAILABLE';
      _session = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshSession() {
    final active = _refreshInFlight;
    if (active != null) return active;

    final operation = _performRefresh();
    _refreshInFlight = operation;
    operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    return operation;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _session?.refreshToken ??
        await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final refreshed = await _api.refresh(refreshToken);
      _session = refreshed;
      _errorCode = null;
      await _persist(refreshed);
      notifyListeners();
      return true;
    } on AuthApiException catch (error) {
      _errorCode = error.code;
      if (_isTerminalAuthError(error)) {
        _session = null;
        await _clearStoredTokens();
        notifyListeners();
      }
      return false;
    } catch (_) {
      _errorCode = 'SERVICE_UNAVAILABLE';
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    return _run(() => _api.login(email: email.trim(), password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String preferredLanguage,
  }) async {
    return _run(
      () => _api.register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        preferredLanguage: preferredLanguage,
      ),
    );
  }

  Future<bool> requestPasswordReset(String email) async {
    _loading = true;
    _errorCode = null;
    notifyListeners();
    try {
      await _api.requestPasswordReset(email.trim());
      return true;
    } on AuthApiException catch (error) {
      _errorCode = error.code;
      return false;
    } catch (_) {
      _errorCode = 'SERVICE_UNAVAILABLE';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    _session = null;
    _errorCode = null;
    await _clearStoredTokens();
    notifyListeners();

    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {
        // Local logout must always succeed even when the server is unavailable.
      }
    }
  }

  Future<bool> _run(Future<AuthSession> Function() operation) async {
    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      _session = await operation();
      await _persist(_session!);
      return true;
    } on AuthApiException catch (error) {
      _errorCode = error.code;
      return false;
    } catch (_) {
      _errorCode = 'SERVICE_UNAVAILABLE';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  bool _isTerminalAuthError(AuthApiException error) =>
      error.statusCode == 401 ||
      error.statusCode == 403 ||
      error.code == 'INVALID_REFRESH_TOKEN' ||
      error.code == 'SESSION_REVOKED';

  Future<void> _persist(AuthSession session) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
    ]);
  }

  Future<void> _clearStoredTokens() => Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../auth/auth_session_controller.dart';
import '../services/app_api.dart';

class AccountDeletionShell extends StatefulWidget {
  const AccountDeletionShell({
    super.key,
    required this.controller,
    required this.child,
  });

  final AuthSessionController controller;
  final Widget child;

  @override
  State<AccountDeletionShell> createState() => _AccountDeletionShellState();
}

class _AccountDeletionShellState extends State<AccountDeletionShell> {
  bool _panelOpen = false;
  bool _deleting = false;
  String? _error;

  String get _language => widget.controller.session?.user.preferredLanguage ?? 'en';
  TextDirection get _direction => _language == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  String _text(String key) {
    const values = <String, Map<String, String>>{
      'tr': {
        'privacy': 'Gizlilik ve hesap',
        'title': 'Hesabımı sil',
        'body': 'Bu işlem hesabını, aktif oturumlarını, kişisel tercihlerini, favorilerini ve bildirim cihaz kayıtlarını kalıcı olarak siler. Restoran işletme kayıtları yasal/işletmesel nedenlerle kullanıcı üyeliğinden ayrıştırılarak kalabilir.',
        'delete': 'HESABI KALICI OLARAK SİL',
        'cancel': 'Vazgeç',
        'working': 'Hesap siliniyor…',
        'failed': 'Hesap silinemedi. Bağlantını kontrol edip tekrar dene.',
      },
      'de': {
        'privacy': 'Datenschutz & Konto',
        'title': 'Konto löschen',
        'body': 'Dadurch werden dein Konto, aktive Sitzungen, persönliche Einstellungen, Favoriten und Push-Geräte dauerhaft gelöscht.',
        'delete': 'KONTO ENDGÜLTIG LÖSCHEN',
        'cancel': 'Abbrechen',
        'working': 'Konto wird gelöscht…',
        'failed': 'Konto konnte nicht gelöscht werden.',
      },
      'fr': {
        'privacy': 'Confidentialité et compte',
        'title': 'Supprimer mon compte',
        'body': 'Cette action supprime définitivement le compte, les sessions actives, les préférences, les favoris et les appareils de notification.',
        'delete': 'SUPPRIMER DÉFINITIVEMENT',
        'cancel': 'Annuler',
        'working': 'Suppression du compte…',
        'failed': 'Impossible de supprimer le compte.',
      },
      'es': {
        'privacy': 'Privacidad y cuenta',
        'title': 'Eliminar mi cuenta',
        'body': 'Esta acción elimina permanentemente la cuenta, las sesiones activas, preferencias, favoritos y dispositivos de notificación.',
        'delete': 'ELIMINAR DEFINITIVAMENTE',
        'cancel': 'Cancelar',
        'working': 'Eliminando cuenta…',
        'failed': 'No se pudo eliminar la cuenta.',
      },
      'ar': {
        'privacy': 'الخصوصية والحساب',
        'title': 'حذف حسابي',
        'body': 'سيؤدي هذا إلى حذف الحساب والجلسات النشطة والتفضيلات والمفضلات وأجهزة الإشعارات نهائيًا.',
        'delete': 'حذف الحساب نهائيًا',
        'cancel': 'إلغاء',
        'working': 'جارٍ حذف الحساب…',
        'failed': 'تعذر حذف الحساب.',
      },
      'en': {
        'privacy': 'Privacy & account',
        'title': 'Delete my account',
        'body': 'This permanently deletes your account, active sessions, personal preferences, favorites and registered push devices. Restaurant business records may remain separated from your user membership where legally or operationally required.',
        'delete': 'PERMANENTLY DELETE ACCOUNT',
        'cancel': 'Cancel',
        'working': 'Deleting account…',
        'failed': 'Account deletion failed. Check your connection and try again.',
      },
    };
    return (values[_language] ?? values['en']!)[key] ?? key;
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await _sendDelete();
      await widget.controller.logout();
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = _text('failed');
        });
      }
    }
  }

  Future<void> _sendDelete({bool refreshed = false}) async {
    final token = widget.controller.session?.accessToken;
    if (token == null) throw StateError('Missing authenticated session');

    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse('${AppApi.baseUrl}/v1/me/account'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(const {'confirmation': 'DELETE'}));
      final response = await request.close().timeout(const Duration(seconds: 15));
      await response.drain<void>();

      if (response.statusCode == HttpStatus.noContent) return;
      if (response.statusCode == HttpStatus.unauthorized && !refreshed) {
        final didRefresh = await widget.controller.refreshSession();
        if (didRefresh) {
          await _sendDelete(refreshed: true);
          return;
        }
      }
      throw HttpException('Account deletion failed: ${response.statusCode}');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQueryData.fromView(View.of(context)).padding.top;
    final overlayTheme = ThemeData.dark(useMaterial3: true);

    return Directionality(
      textDirection: _direction,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: safeTop + 8,
            right: _direction == TextDirection.ltr ? 10 : null,
            left: _direction == TextDirection.rtl ? 10 : null,
            child: Theme(
              data: overlayTheme,
              child: Material(
                color: const Color(0xDD101426),
                shape: const CircleBorder(),
                elevation: 4,
                child: Semantics(
                  label: _text('privacy'),
                  button: true,
                  child: IconButton(
                    onPressed: () => setState(() => _panelOpen = true),
                    icon: const Icon(Icons.privacy_tip_outlined),
                  ),
                ),
              ),
            ),
          ),
          if (_panelOpen)
            Positioned.fill(
              child: Theme(
                data: overlayTheme,
                child: Material(
                  color: Colors.black54,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, safeTop + 16, 16, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Card(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _text('title'),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(_text('body')),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _deleting ? null : _deleteAccount,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  icon: _deleting
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.delete_forever),
                                  label: Text(
                                    _deleting ? _text('working') : _text('delete'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _deleting
                                      ? null
                                      : () => setState(() => _panelOpen = false),
                                  child: Text(_text('cancel')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

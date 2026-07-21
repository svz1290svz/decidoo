import 'package:flutter/material.dart';

import '../production_shell.dart';
import 'auth_session_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.controller});

  final AuthSessionController controller;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isLoading && !widget.controller.isAuthenticated) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF070A16),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (widget.controller.isAuthenticated) {
      return ProductionShell(controller: widget.controller);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _AuthPage(controller: widget.controller),
    );
  }
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({required this.controller});

  final AuthSessionController controller;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < (_register ? 10 : 1)) {
      _show('E-posta ve şifre bilgilerini kontrol edin.');
      return;
    }
    if (_register && _name.text.trim().length < 2) {
      _show('Adınızı girin.');
      return;
    }

    final success = _register
        ? await widget.controller.register(
            email: email,
            password: password,
            displayName: _name.text,
            preferredLanguage: 'tr',
          )
        : await widget.controller.login(email: email, password: password);

    if (!success && mounted) {
      _show(_errorMessage(widget.controller.errorCode));
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(String? code) => switch (code) {
        'EMAIL_ALREADY_REGISTERED' => 'Bu e-posta daha önce kullanılmış.',
        'INVALID_CREDENTIALS' => 'E-posta veya şifre hatalı.',
        'ACCOUNT_UNAVAILABLE' => 'Hesap şu anda kullanılamıyor.',
        'SERVICE_UNAVAILABLE' => 'Sunucuya ulaşılamadı. Bağlantıyı kontrol edin.',
        _ => 'İşlem tamamlanamadı. Tekrar deneyin.',
      };

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6B35);
    return Scaffold(
      backgroundColor: const Color(0xFF070A16),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF101426),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x33725CFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'DECIDOO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register ? 'Ücretsiz hesabını oluştur' : 'Yemek kararına devam et',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9DA3BA)),
                    ),
                    const SizedBox(height: 28),
                    if (_register) ...[
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ad soyad',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: _register ? 'Şifre (en az 10 karakter)' : 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.controller.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: orange,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: widget.controller.isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'HESAP OLUŞTUR' : 'GİRİŞ YAP'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.controller.isLoading
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(_register ? 'Zaten hesabım var' : 'Yeni hesap oluştur'),
                    ),
                    if (_register)
                      const Text(
                        'Devam ederek kullanım koşullarını ve gizlilik politikasını kabul edersiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF9DA3BA)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

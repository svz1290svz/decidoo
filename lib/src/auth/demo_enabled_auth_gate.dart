import 'package:flutter/material.dart';

import '../app.dart';
import 'auth_gate.dart';
import 'auth_session_controller.dart';

class DemoEnabledAuthGate extends StatefulWidget {
  const DemoEnabledAuthGate({super.key, required this.controller});

  final AuthSessionController controller;

  @override
  State<DemoEnabledAuthGate> createState() => _DemoEnabledAuthGateState();
}

class _DemoEnabledAuthGateState extends State<DemoEnabledAuthGate> {
  bool _showRealLogin = false;
  bool _showDemo = false;

  @override
  Widget build(BuildContext context) {
    if (_showDemo) {
      return const DecidooApp();
    }
    if (_showRealLogin) {
      return AuthGate(controller: widget.controller);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
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
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Uygulamayı hemen dene veya canlı sunucu hesabınla giriş yap.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9DA3BA)),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        key: const Key('demo-entry-button'),
                        onPressed: () => setState(() => _showDemo = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          minimumSize: const Size.fromHeight(56),
                        ),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('DEMO OLARAK DEVAM ET'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showRealLogin = true),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('HESAPLA GİRİŞ YAP'),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Not: Hesapla giriş için Decidoo canlı API sunucusunun yayınlanmış olması gerekir. Demo modu internetsiz çalışır.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9DA3BA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

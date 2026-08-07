import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'auth/auth_session_controller.dart';
import 'auth/demo_enabled_auth_gate.dart';
import 'localized_store_ready_production_app.dart';
import 'management_app.dart';
import 'privacy/account_deletion_shell.dart';

class StoreReadyGate extends StatefulWidget {
  const StoreReadyGate({super.key, required this.controller});

  final AuthSessionController controller;

  @override
  State<StoreReadyGate> createState() => _StoreReadyGateState();
}

class _StoreReadyGateState extends State<StoreReadyGate> {
  static const bool _allowDemo = bool.fromEnvironment(
    'ALLOW_DEMO',
    defaultValue: false,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isAuthenticated) {
      return _allowDemo
          ? DemoEnabledAuthGate(controller: widget.controller)
          : AuthGate(controller: widget.controller);
    }

    final role = widget.controller.session?.user.role ?? 'USER';
    if (role == 'ADMIN' ||
        role == 'RESTAURANT_OWNER' ||
        role == 'RESTAURANT_STAFF') {
      return ManagementApp(
        controller: widget.controller,
        isAdmin: role == 'ADMIN',
      );
    }

    return AccountDeletionShell(
      controller: widget.controller,
      child: LocalizedStoreReadyProductionApp(controller: widget.controller),
    );
  }
}

import 'package:flutter/material.dart';

import 'auth/auth_session_controller.dart';
import 'auth/demo_enabled_auth_gate.dart';
import 'localized_store_ready_production_app.dart';
import 'management_app.dart';

class StoreReadyGate extends StatefulWidget {
  const StoreReadyGate({super.key, required this.controller});

  final AuthSessionController controller;

  @override
  State<StoreReadyGate> createState() => _StoreReadyGateState();
}

class _StoreReadyGateState extends State<StoreReadyGate> {
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
      return DemoEnabledAuthGate(controller: widget.controller);
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

    return LocalizedStoreReadyProductionApp(controller: widget.controller);
  }
}

import 'package:flutter/material.dart';

import 'auth/auth_session_controller.dart';
import 'services/app_api.dart';

class ManagementApp extends StatefulWidget {
  const ManagementApp({
    super.key,
    required this.controller,
    required this.isAdmin,
  });

  final AuthSessionController controller;
  final bool isAdmin;

  @override
  State<ManagementApp> createState() => _ManagementAppState();
}

class _ManagementAppState extends State<ManagementApp> {
  late final AppApi _api = AppApi(widget.controller);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(widget.isAdmin ? 'Decidoo Admin' : 'Restoran Yönetimi'),
          actions: [
            IconButton(
              tooltip: 'Çıkış yap',
              onPressed: widget.controller.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: widget.isAdmin
              ? _AdminPanel(api: _api)
              : _OwnerPanel(api: _api),
        ),
      ),
    );
  }
}

class _AdminPanel extends StatefulWidget {
  const _AdminPanel({required this.api});
  final AppApi api;

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  late Future<List<Map<String, dynamic>>> _future =
      widget.api.adminRestaurants();

  void _reload() {
    setState(() => _future = widget.api.adminRestaurants());
  }

  Future<void> _moderate(String id, String status) async {
    await widget.api.moderateRestaurant(id: id, status: status);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future;
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Onay bekleyen restoranlar',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const _MessageCard('Restoranlar alınamadı.');
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const _MessageCard('Onay bekleyen restoran yok.');
              }
              return Column(
                children: items.map((restaurant) {
                  final id = restaurant['id'].toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant['name']?.toString() ?? 'Restoran',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${restaurant['city'] ?? ''} · '
                            '${restaurant['addressLine'] ?? ''}',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _moderate(id, 'ACTIVE'),
                                  icon: const Icon(Icons.check),
                                  label: const Text('ONAYLA'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _moderate(id, 'REJECTED'),
                                  icon: const Icon(Icons.close),
                                  label: const Text('REDDET'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OwnerPanel extends StatefulWidget {
  const _OwnerPanel({required this.api});
  final AppApi api;

  @override
  State<_OwnerPanel> createState() => _OwnerPanelState();
}

class _OwnerPanelState extends State<_OwnerPanel> {
  late Future<List<Map<String, dynamic>>> _future =
      widget.api.ownerRestaurants();

  void _reload() {
    setState(() => _future = widget.api.ownerRestaurants());
  }

  Future<void> _showCreateDialog() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController(text: 'Eskişehir');
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restoran ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Restoran adı'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Adres'),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Şehir'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().length < 2 || address.text.trim().isEmpty) {
                return;
              }
              await widget.api.createRestaurant(
                name: name.text.trim(),
                addressLine: address.text.trim(),
                city: city.text.trim(),
                latitude: 39.7767,
                longitude: 30.5206,
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    city.dispose();
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add_business),
          label: const Text('RESTORAN EKLE'),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _MessageCard('Restoranlar alınamadı.');
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const _MessageCard('Henüz restoran eklenmemiş.');
            }
            return Column(
              children: items.map((restaurant) {
                final status = restaurant['status']?.toString() ?? 'DRAFT';
                return Card(
                  child: ListTile(
                    title: Text(restaurant['name']?.toString() ?? 'Restoran'),
                    subtitle: Text('Durum: $status'),
                    trailing: status == 'DRAFT' || status == 'REJECTED'
                        ? FilledButton(
                            onPressed: () async {
                              await widget.api
                                  .submitRestaurant(restaurant['id'].toString());
                              if (mounted) _reload();
                            },
                            child: const Text('Onaya gönder'),
                          )
                        : null,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message),
      ),
    );
  }
}

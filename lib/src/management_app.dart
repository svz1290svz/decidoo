import 'package:flutter/material.dart';

import 'auth/auth_session_controller.dart';
import 'services/app_api.dart';
import 'services/management_api.dart';

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
  late final AppApi _appApi = AppApi(widget.controller);
  late final ManagementApi _managementApi = ManagementApi(widget.controller);

  @override
  void dispose() {
    _managementApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              ? _AdminPanel(api: _managementApi)
              : _OwnerPanel(appApi: _appApi, api: _managementApi),
        ),
      ),
    );
  }
}

class _AdminPanel extends StatefulWidget {
  const _AdminPanel({required this.api});
  final ManagementApi api;

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  late Future<Map<String, dynamic>> _dashboard = widget.api.adminDashboard();
  late Future<List<Map<String, dynamic>>> _restaurants =
      widget.api.adminRestaurants();

  Future<void> _reload() async {
    setState(() {
      _dashboard = widget.api.adminDashboard();
      _restaurants = widget.api.adminRestaurants();
    });
    await Future.wait([_dashboard, _restaurants]);
  }

  Future<void> _moderate(String id, String status) async {
    await widget.api.moderateRestaurant(id, status);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Operasyon özeti',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _dashboard,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const _LoadingCard();
              }
              final data = snapshot.data!;
              final totals = data['totals'] as Map<String, dynamic>? ?? const {};
              final growth = data['growth30d'] as Map<String, dynamic>? ?? const {};
              final rates = data['rates'] as Map<String, dynamic>? ?? const {};
              final metrics = <(String, String, IconData)>[
                ('Kullanıcı', '${totals['users'] ?? 0}', Icons.people_alt_outlined),
                ('Aktif restoran', '${totals['activeRestaurants'] ?? 0}', Icons.storefront_outlined),
                ('Yemek', '${totals['availableMeals'] ?? 0}', Icons.restaurant_menu),
                ('Öneri', '${totals['recommendations'] ?? 0}', Icons.auto_awesome),
                ('Favori', '${totals['favorites'] ?? 0}', Icons.favorite_outline),
                ('30g yeni kullanıcı', '${growth['users'] ?? 0}', Icons.trending_up),
                ('30g yeni restoran', '${growth['restaurants'] ?? 0}', Icons.add_business),
                (
                  'Etkileşim',
                  '${(((rates['recommendationEngagement'] as num?) ?? 0) * 100).toStringAsFixed(1)}%',
                  Icons.insights,
                ),
              ];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.1 : 1.7,
                    children: metrics
                        .map((metric) => _MetricCard(
                              label: metric.$1,
                              value: metric.$2,
                              icon: metric.$3,
                            ))
                        .toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 26),
          const Text(
            'Onay bekleyen restoranlar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _restaurants,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const _LoadingCard();
              final items = snapshot.data!;
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text('${restaurant['city'] ?? ''} · ${restaurant['addressLine'] ?? ''}'),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _moderate(id, 'ACTIVE'),
                                icon: const Icon(Icons.check),
                                label: const Text('ONAYLA'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _moderate(id, 'REJECTED'),
                                icon: const Icon(Icons.close),
                                label: const Text('REDDET'),
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
  const _OwnerPanel({required this.appApi, required this.api});
  final AppApi appApi;
  final ManagementApi api;

  @override
  State<_OwnerPanel> createState() => _OwnerPanelState();
}

class _OwnerPanelState extends State<_OwnerPanel> {
  late Future<List<Map<String, dynamic>>> _future = widget.api.ownerRestaurants();

  void _reload() => setState(() => _future = widget.api.ownerRestaurants());

  Future<void> _showCreateRestaurant() async {
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
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Restoran adı')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Adres')),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'Şehir')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().length < 2 || address.text.trim().isEmpty) return;
              await widget.appApi.createRestaurant(
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

  Future<void> _showCategoryDialog(String restaurantId) async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Menü kategorisi ekle'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Kategori adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await widget.api.createCategory(restaurantId: restaurantId, name: name.text.trim());
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    name.dispose();
    if (saved == true && mounted) _reload();
  }

  Future<void> _showMealDialog(
    String restaurantId,
    List<Map<String, dynamic>> categories,
    String currency,
  ) async {
    final name = TextEditingController();
    final price = TextEditingController();
    final imageUrl = TextEditingController();
    String? categoryId = categories.isEmpty ? null : categories.first['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yemek ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Yemek adı')),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Fiyat ($currency)'),
                ),
                TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Fotoğraf URL')), 
                if (categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: categories
                        .map((item) => DropdownMenuItem(
                              value: item['id'].toString(),
                              child: Text(item['name']?.toString() ?? 'Kategori'),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => categoryId = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final parsedPrice = double.tryParse(price.text.replaceAll(',', '.'));
                if (name.text.trim().length < 2 || parsedPrice == null || parsedPrice <= 0) return;
                await widget.api.createMeal(
                  restaurantId: restaurantId,
                  categoryId: categoryId,
                  name: name.text.trim(),
                  price: parsedPrice,
                  currency: currency,
                  imageUrl: imageUrl.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    price.dispose();
    imageUrl.dispose();
    if (saved == true && mounted) _reload();
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
          FilledButton.icon(
            onPressed: _showCreateRestaurant,
            icon: const Icon(Icons.add_business),
            label: const Text('RESTORAN EKLE'),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const _LoadingCard();
              final items = snapshot.data!;
              if (items.isEmpty) return const _MessageCard('Henüz restoran eklenmemiş.');
              return Column(
                children: items.map((restaurant) {
                  final id = restaurant['id'].toString();
                  final status = restaurant['status']?.toString() ?? 'DRAFT';
                  final currency = restaurant['currency']?.toString() ?? 'TRY';
                  final categories = (restaurant['categories'] as List? ?? const [])
                      .cast<Map<String, dynamic>>();
                  final meals = (restaurant['meals'] as List? ?? const [])
                      .cast<Map<String, dynamic>>();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(restaurant['name']?.toString() ?? 'Restoran'),
                      subtitle: Text('Durum: $status · ${meals.length} yemek'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showCategoryDialog(id),
                              icon: const Icon(Icons.category_outlined),
                              label: const Text('Kategori ekle'),
                            ),
                            FilledButton.icon(
                              onPressed: () => _showMealDialog(id, categories, currency),
                              icon: const Icon(Icons.add),
                              label: const Text('Yemek ekle'),
                            ),
                            if (status == 'DRAFT' || status == 'REJECTED')
                              TextButton(
                                onPressed: () async {
                                  await widget.appApi.submitRestaurant(id);
                                  if (mounted) _reload();
                                },
                                child: const Text('Onaya gönder'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (categories.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              children: categories
                                  .map((category) => Chip(label: Text(category['name']?.toString() ?? 'Kategori')))
                                  .toList(),
                            ),
                          ),
                        if (meals.isEmpty)
                          const _MessageCard('Bu restoranda henüz yemek yok.')
                        else
                          ...meals.map((meal) {
                            final available = meal['isAvailable'] == true;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: meal['imageUrl'] == null
                                  ? const CircleAvatar(child: Icon(Icons.restaurant))
                                  : CircleAvatar(backgroundImage: NetworkImage(meal['imageUrl'].toString())),
                              title: Text(meal['name']?.toString() ?? 'Yemek'),
                              subtitle: Text('${meal['price'] ?? '-'} $currency'),
                              trailing: Switch(
                                value: available,
                                onChanged: (value) async {
                                  await widget.api.updateMeal(
                                    mealId: meal['id'].toString(),
                                    isAvailable: value,
                                  );
                                  if (mounted) _reload();
                                },
                              ),
                            );
                          }),
                      ],
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message),
        ),
      );
}

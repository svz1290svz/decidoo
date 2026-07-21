import 'package:flutter/material.dart';

import 'auth/auth_session_controller.dart';
import 'services/app_api.dart';

const _ink = Color(0xFF070A16);
const _panel = Color(0xFF101426);
const _orange = Color(0xFFFF6B35);
const _muted = Color(0xFF9DA3BA);

class ProductionShell extends StatefulWidget {
  const ProductionShell({super.key, required this.controller});
  final AuthSessionController controller;

  @override
  State<ProductionShell> createState() => _ProductionShellState();
}

class _ProductionShellState extends State<ProductionShell> {
  late final AppApi _api = AppApi(widget.controller);
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DiscoverPage(api: _api),
      _RecommendationPage(api: _api),
      _FavoritesPage(api: _api),
      _AccountPage(api: _api, controller: widget.controller),
    ];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        colorScheme: ColorScheme.fromSeed(seedColor: _orange, brightness: Brightness.dark),
        cardTheme: CardThemeData(
          color: _panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: Scaffold(
        body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Keşfet'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Öneri'),
            NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Favoriler'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Hesabım'),
          ],
        ),
      ),
    );
  }
}

class _DiscoverPage extends StatefulWidget {
  const _DiscoverPage({required this.api});
  final AppApi api;

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_DiscoverPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future = widget.api.restaurants();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() => setState(() => _future = widget.api.restaurants(query: _search.text));

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Header(title: 'DECIDOO', subtitle: 'Gerçek restoranları keşfet'),
            const SizedBox(height: 20),
            TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Restoran, şehir veya yemek ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) return const _ErrorCard();
                final items = snapshot.data ?? const [];
                if (items.isEmpty) return const _EmptyCard(text: 'Henüz restoran bulunamadı.');
                return Column(
                  children: items.map((restaurant) => _RestaurantCard(api: widget.api, restaurant: restaurant)).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class _RecommendationPage extends StatefulWidget {
  const _RecommendationPage({required this.api});
  final AppApi api;

  @override
  State<_RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<_RecommendationPage> {
  double _budget = 500;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(title: 'Bugün ne yesem?', subtitle: 'Bütçene göre gerçek öneriler'),
          const SizedBox(height: 26),
          Text('Azami bütçe: ${_budget.round()} TL', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _budget, min: 100, max: 2000, divisions: 19, onChanged: (value) => setState(() => _budget = value)),
          FilledButton.icon(
            onPressed: () => setState(() => _future = widget.api.recommendations(maxBudget: _budget)),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('BANA ÖNER'),
          ),
          const SizedBox(height: 20),
          if (_future != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const _ErrorCard();
                final results = snapshot.data ?? const [];
                if (results.isEmpty) return const _EmptyCard(text: 'Bu filtrelerle sonuç bulunamadı.');
                return Column(
                  children: results.map((item) {
                    final meal = item['meal'] as Map<String, dynamic>? ?? const {};
                    final restaurant = item['restaurant'] as Map<String, dynamic>? ?? const {};
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(18),
                        title: Text(meal['name']?.toString() ?? 'Yemek', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${restaurant['name'] ?? ''}\n${meal['price'] ?? '-'} ${meal['currency'] ?? 'TRY'}'),
                        isThreeLine: true,
                        trailing: item['isSponsored'] == true ? const Chip(label: Text('Sponsorlu')) : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      );
}

class _FavoritesPage extends StatefulWidget {
  const _FavoritesPage({required this.api});
  final AppApi api;

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  late Future<List<Map<String, dynamic>>> _future = widget.api.favorites();
  void _reload() => setState(() => _future = widget.api.favorites());

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(title: 'Favorilerim', subtitle: 'Kaydettiğin restoran ve yemekler'),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return const _ErrorCard();
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const _EmptyCard(text: 'Henüz favorin yok.');
              return Column(
                children: items.map((item) {
                  final restaurant = item['restaurant'] as Map<String, dynamic>?;
                  final meal = item['meal'] as Map<String, dynamic>?;
                  return Card(
                    child: ListTile(
                      title: Text((meal?['name'] ?? restaurant?['name'] ?? 'Favori').toString()),
                      subtitle: Text(meal != null ? 'Yemek' : 'Restoran'),
                      trailing: IconButton(
                        onPressed: () async {
                          await widget.api.removeFavorite(item['id'].toString());
                          _reload();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      );
}

class _AccountPage extends StatefulWidget {
  const _AccountPage({required this.api, required this.controller});
  final AppApi api;
  final AuthSessionController controller;

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  late final _name = TextEditingController(text: widget.controller.session?.user.displayName ?? '');
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(title: 'Hesabım', subtitle: 'Profil ve güvenlik ayarları'),
          const SizedBox(height: 20),
          Text(widget.controller.session?.user.email ?? '', style: const TextStyle(color: _muted)),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Ad soyad', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _run(() => widget.api.updateProfile(displayName: _name.text.trim(), preferredLanguage: 'tr'), 'Profil güncellendi.'),
            child: const Text('PROFİLİ GÜNCELLE'),
          ),
          const SizedBox(height: 30),
          TextField(controller: _currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut şifre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy || _newPassword.text.length < 10
                ? null
                : () => _run(() => widget.api.changePassword(currentPassword: _currentPassword.text, newPassword: _newPassword.text), 'Şifre değiştirildi.'),
            child: const Text('ŞİFREYİ DEĞİŞTİR'),
          ),
          const SizedBox(height: 30),
          TextButton.icon(onPressed: _busy ? null : widget.controller.logout, icon: const Icon(Icons.logout), label: const Text('Çıkış yap')),
        ],
      );
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.api, required this.restaurant});
  final AppApi api;
  final Map<String, dynamic> restaurant;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(radius: 26, child: Icon(Icons.restaurant)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant['name']?.toString() ?? 'Restoran', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${restaurant['city'] ?? ''} ${restaurant['district'] ?? ''}', style: const TextStyle(color: _muted)),
                    Text('⭐ ${restaurant['averageRating'] ?? 0} · ${restaurant['reviewCount'] ?? 0} yorum', style: const TextStyle(color: _muted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await api.addFavorite(restaurantId: restaurant['id'].toString());
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorilere eklendi.')));
                },
                icon: const Icon(Icons.favorite_border),
              ),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted)),
        ],
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();
  @override
  Widget build(BuildContext context) => const _EmptyCard(text: 'Sunucuya ulaşılamadı. Canlı API adresini kontrol edin.');
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Text(text)));
}

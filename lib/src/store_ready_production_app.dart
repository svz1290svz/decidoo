import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth/auth_session_controller.dart';
import 'services/app_api.dart';
import 'services/store_ready_api.dart';

const _ink = Color(0xFF070A16);
const _panel = Color(0xFF101426);
const _orange = Color(0xFFFF6B35);
const _muted = Color(0xFF9DA3BA);

class StoreReadyProductionApp extends StatefulWidget {
  const StoreReadyProductionApp({super.key, required this.controller});

  final AuthSessionController controller;

  @override
  State<StoreReadyProductionApp> createState() => _StoreReadyProductionAppState();
}

class _StoreReadyProductionAppState extends State<StoreReadyProductionApp> {
  late final AppApi _appApi = AppApi(widget.controller);
  late final StoreReadyApi _api = StoreReadyApi(widget.controller, appApi: _appApi);
  var _tab = 0;
  var _syncing = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await _api.syncPending();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncMessage = result.pending > 0
          ? '${result.pending} değişiklik bağlantı bekliyor'
          : result.synced > 0
              ? '${result.synced} değişiklik senkronize edildi'
              : null;
    });
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DiscoverPage(appApi: _appApi, api: _api, onSync: _sync),
      _RecommendationPage(appApi: _appApi, api: _api),
      _FavoritesPage(appApi: _appApi, api: _api, onSync: _sync),
      _AccountPage(controller: widget.controller, api: _api, onSync: _sync),
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
        body: SafeArea(
          child: Column(
            children: [
              if (_syncing || _syncMessage != null)
                MaterialBanner(
                  content: Text(_syncing ? 'Değişiklikler senkronize ediliyor…' : _syncMessage!),
                  leading: _syncing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined),
                  actions: [
                    if (!_syncing)
                      TextButton(onPressed: _sync, child: const Text('TEKRAR DENE')),
                    TextButton(
                      onPressed: () => setState(() => _syncMessage = null),
                      child: const Text('KAPAT'),
                    ),
                  ],
                ),
              Expanded(child: IndexedStack(index: _tab, children: pages)),
            ],
          ),
        ),
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
  const _DiscoverPage({required this.appApi, required this.api, required this.onSync});
  final AppApi appApi;
  final StoreReadyApi api;
  final Future<void> Function() onSync;

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_DiscoverPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future = widget.appApi.restaurants();

  void _reload() {
    setState(() => _future = widget.appApi.restaurants(query: _search.text.trim()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await widget.onSync();
        _reload();
        await _future;
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(title: 'DECIDOO', subtitle: 'Yakınındaki gerçek menüleri keşfet'),
          const SizedBox(height: 18),
          SearchBar(
            controller: _search,
            hintText: 'Restoran, şehir veya yemek ara',
            leading: const Icon(Icons.search),
            onSubmitted: (_) => _reload(),
            trailing: [IconButton(onPressed: _reload, icon: const Icon(Icons.arrow_forward))],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const _LoadingCard();
              if (snapshot.hasError) return const _MessageCard('Restoranlar alınamadı.');
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const _MessageCard('Bu aramayla restoran bulunamadı.');
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: columns == 1 ? 2.05 : 1.35,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _RestaurantCard(
                      restaurant: items[index],
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _RestaurantDetailPage(
                            slug: items[index]['slug'].toString(),
                            api: widget.api,
                          ),
                        ),
                      ),
                      onFavorite: () async {
                        await widget.api.addFavorite(
                          restaurantId: items[index]['id'].toString(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Favorilere eklendi veya senkronizasyon sırasına alındı.')),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant, required this.onOpen, required this.onFavorite});
  final Map<String, dynamic> restaurant;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: restaurant['logoUrl'] == null
                      ? null
                      : NetworkImage(restaurant['logoUrl'].toString()),
                  child: restaurant['logoUrl'] == null ? const Icon(Icons.restaurant) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant['name']?.toString() ?? 'Restoran',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text('${restaurant['city'] ?? ''} ${restaurant['district'] ?? ''}',
                          style: const TextStyle(color: _muted)),
                      Text('⭐ ${restaurant['averageRating'] ?? 0} · ${restaurant['reviewCount'] ?? 0} yorum',
                          style: const TextStyle(color: _muted)),
                      const SizedBox(height: 6),
                      Text(restaurant['isOpen'] == true ? 'Açık' : 'Kapalı',
                          style: TextStyle(
                            color: restaurant['isOpen'] == true ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                ),
                IconButton(onPressed: onFavorite, icon: const Icon(Icons.favorite_border)),
              ],
            ),
          ),
        ),
      );
}

class _RestaurantDetailPage extends StatefulWidget {
  const _RestaurantDetailPage({required this.slug, required this.api});
  final String slug;
  final StoreReadyApi api;

  @override
  State<_RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<_RestaurantDetailPage> {
  late final Future<Map<String, dynamic>> _future = widget.api.restaurantDetail(widget.slug);

  Future<void> _navigate(Map<String, dynamic> restaurant) async {
    final lat = restaurant['latitude'];
    final lng = restaurant['longitude'];
    final label = Uri.encodeComponent(restaurant['name']?.toString() ?? 'Decidoo restaurant');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$label');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restoran detayı')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final restaurant = snapshot.data!;
          final categories = (restaurant['categories'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (restaurant['coverUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    restaurant['coverUrl'].toString(),
                    height: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                restaurant['name']?.toString() ?? 'Restoran',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(restaurant['description']?.toString() ?? '', style: const TextStyle(color: _muted)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _navigate(restaurant),
                    icon: const Icon(Icons.directions),
                    label: const Text('YOL TARİFİ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.api.addFavorite(restaurantId: restaurant['id'].toString()),
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('FAVORİ'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Menü', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                const _MessageCard('Menü henüz yayınlanmadı.')
              else
                ...categories.map((category) {
                  final meals = (category['meals'] as List? ?? const [])
                      .cast<Map<String, dynamic>>();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(category['name']?.toString() ?? 'Kategori'),
                      children: meals
                          .map((meal) => ListTile(
                                leading: meal['imageUrl'] == null
                                    ? const CircleAvatar(child: Icon(Icons.restaurant_menu))
                                    : CircleAvatar(backgroundImage: NetworkImage(meal['imageUrl'].toString())),
                                title: Text(meal['name']?.toString() ?? 'Yemek'),
                                subtitle: Text(meal['description']?.toString() ?? ''),
                                trailing: Text(
                                  '${meal['price'] ?? '-'} ${meal['currency'] ?? restaurant['currency'] ?? 'TRY'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ))
                          .toList(),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _RecommendationPage extends StatefulWidget {
  const _RecommendationPage({required this.appApi, required this.api});
  final AppApi appApi;
  final StoreReadyApi api;

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
          const _Header(title: 'Bugün ne yesem?', subtitle: 'Bütçene ve davranışlarına göre kişisel karar'),
          const SizedBox(height: 22),
          Text('Azami bütçe: ${_budget.round()} TL'),
          Slider(
            value: _budget,
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (value) => setState(() => _budget = value),
          ),
          FilledButton.icon(
            onPressed: () => setState(() {
              _future = widget.appApi.recommendations(maxBudget: _budget);
            }),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('BANA ÖNER'),
          ),
          const SizedBox(height: 18),
          if (_future != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const _LoadingCard();
                return Column(
                  children: snapshot.data!.map((item) {
                    final meal = (item['meal'] as Map?)?.cast<String, dynamic>() ?? const {};
                    final restaurant = (item['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {};
                    return Card(
                      child: ListTile(
                        title: Text(meal['name']?.toString() ?? 'Yemek'),
                        subtitle: Text('${restaurant['name'] ?? ''}\n${meal['price'] ?? '-'} ${meal['currency'] ?? 'TRY'}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          onPressed: () => widget.api.addFavorite(mealId: meal['id'].toString()),
                          icon: const Icon(Icons.favorite_border),
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

class _FavoritesPage extends StatefulWidget {
  const _FavoritesPage({required this.appApi, required this.api, required this.onSync});
  final AppApi appApi;
  final StoreReadyApi api;
  final Future<void> Function() onSync;

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  late Future<List<Map<String, dynamic>>> _future = widget.appApi.favorites();
  void _reload() => setState(() => _future = widget.appApi.favorites());

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async {
          await widget.onSync();
          _reload();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Header(title: 'Favorilerim', subtitle: 'Kaydettiğin restoran ve yemekler'),
            const SizedBox(height: 18),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const _LoadingCard();
                if (snapshot.data!.isEmpty) return const _MessageCard('Henüz favorin yok.');
                return Column(
                  children: snapshot.data!.map((item) {
                    final restaurant = item['restaurant'] as Map<String, dynamic>?;
                    final meal = item['meal'] as Map<String, dynamic>?;
                    return Card(
                      child: ListTile(
                        title: Text((meal?['name'] ?? restaurant?['name'] ?? 'Favori').toString()),
                        subtitle: Text(meal != null ? 'Yemek' : 'Restoran'),
                        trailing: IconButton(
                          onPressed: () async {
                            await widget.api.removeFavorite(item['id'].toString());
                            if (mounted) _reload();
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
        ),
      );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.controller, required this.api, required this.onSync});
  final AuthSessionController controller;
  final StoreReadyApi api;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Header(title: 'Hesabım', subtitle: 'Profil, senkronizasyon ve güvenlik'),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(controller.session?.user.displayName ?? 'Decidoo kullanıcısı'),
              subtitle: Text(controller.session?.user.email ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync),
            label: const Text('ŞİMDİ SENKRONİZE ET'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout),
            label: const Text('ÇIKIŞ YAP'),
          ),
        ],
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text),
        ),
      );
}

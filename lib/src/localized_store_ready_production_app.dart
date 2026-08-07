import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth/auth_session_controller.dart';
import 'localization/app_strings.dart';
import 'services/app_api.dart';
import 'services/store_ready_api.dart';

const _ink = Color(0xFF070A16);
const _panel = Color(0xFF101426);
const _orange = Color(0xFFFF6B35);
const _muted = Color(0xFF9DA3BA);

class LocalizedStoreReadyProductionApp extends StatefulWidget {
  const LocalizedStoreReadyProductionApp({
    super.key,
    required this.controller,
  });

  final AuthSessionController controller;

  @override
  State<LocalizedStoreReadyProductionApp> createState() =>
      _LocalizedStoreReadyProductionAppState();
}

class _LocalizedStoreReadyProductionAppState
    extends State<LocalizedStoreReadyProductionApp> {
  late final AppApi _appApi = AppApi(widget.controller);
  late final StoreReadyApi _storeApi =
      StoreReadyApi(widget.controller, appApi: _appApi);
  late String _language = _initialLanguage();
  int _tab = 0;
  bool _syncing = false;
  String? _syncMessage;

  String _initialLanguage() {
    final value = widget.controller.session?.user.preferredLanguage ?? 'tr';
    return AppStrings.supportedCodes.contains(value) ? value : 'en';
  }

  AppStrings get _s => AppStrings(_language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await _storeApi.syncPending();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncMessage = result.pending > 0
          ? '${result.pending} ${_s.t('pendingChanges')}'
          : result.synced > 0
              ? '${result.synced} ${_s.t('syncedChanges')}'
              : null;
    });
  }

  Future<void> _changeLanguage(String code) async {
    if (code == _language) return;
    setState(() => _language = code);
    await _appApi.updateProfile(
      displayName: widget.controller.session?.user.displayName ?? '',
      preferredLanguage: code,
    );
  }

  @override
  void dispose() {
    _storeApi.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DiscoverPage(appApi: _appApi, storeApi: _storeApi, strings: _s),
      _RecommendationPage(
        appApi: _appApi,
        storeApi: _storeApi,
        strings: _s,
      ),
      _FavoritesPage(appApi: _appApi, storeApi: _storeApi, strings: _s),
      _AccountPage(
        controller: widget.controller,
        strings: _s,
        language: _language,
        onLanguageChanged: _changeLanguage,
        onSync: _sync,
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _orange,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: _panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      home: Directionality(
        textDirection: _s.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (_syncing || _syncMessage != null)
                  MaterialBanner(
                    content: Text(
                      _syncing ? _s.t('syncing') : _syncMessage!,
                    ),
                    actions: [
                      if (!_syncing)
                        TextButton(onPressed: _sync, child: Text(_s.t('retry'))),
                      TextButton(
                        onPressed: () => setState(() => _syncMessage = null),
                        child: Text(_s.t('dismiss')),
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
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                label: _s.t('discover'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                label: _s.t('recommend'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.favorite_border),
                label: _s.t('favorites'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: _s.t('account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverPage extends StatefulWidget {
  const _DiscoverPage({
    required this.appApi,
    required this.storeApi,
    required this.strings,
  });

  final AppApi appApi;
  final StoreReadyApi storeApi;
  final AppStrings strings;

  @override
  State<_DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<_DiscoverPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _restaurants =
      widget.appApi.restaurants();

  void _reload() => setState(() {
        _restaurants = widget.appApi.restaurants(query: _search.text.trim());
      });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(title: 'DECIDOO', subtitle: widget.strings.t('discoverSubtitle')),
          const SizedBox(height: 16),
          SearchBar(
            controller: _search,
            hintText: widget.strings.t('searchHint'),
            leading: const Icon(Icons.search),
            onSubmitted: (_) => _reload(),
            trailing: [
              IconButton(onPressed: _reload, icon: const Icon(Icons.arrow_forward)),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _restaurants,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const _LoadingCard();
              if (snapshot.data!.isEmpty) {
                return _MessageCard(widget.strings.t('restaurantsEmpty'));
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (restaurant) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.restaurant),
                          ),
                          title: Text(
                            restaurant['name']?.toString() ??
                                widget.strings.t('restaurant'),
                          ),
                          subtitle: Text(
                            '${restaurant['city'] ?? ''} ${restaurant['district'] ?? ''}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _RestaurantDetailPage(
                                slug: restaurant['slug'].toString(),
                                storeApi: widget.storeApi,
                                strings: widget.strings,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () => widget.storeApi.addFavorite(
                              restaurantId: restaurant['id'].toString(),
                            ),
                            icon: const Icon(Icons.favorite_border),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      );
}

class _RecommendationPage extends StatefulWidget {
  const _RecommendationPage({
    required this.appApi,
    required this.storeApi,
    required this.strings,
  });

  final AppApi appApi;
  final StoreReadyApi storeApi;
  final AppStrings strings;

  @override
  State<_RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<_RecommendationPage> {
  double _budget = 500;
  Future<List<Map<String, dynamic>>>? _recommendations;

  Future<void> _record(
    Map<String, dynamic> item,
    String action,
  ) async {
    if (item['_attributionLive'] != true) return;
    final sessionId = item['_recommendationSessionId']?.toString();
    final restaurant =
        (item['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {};
    final meal = (item['meal'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (sessionId == null || restaurant['id'] == null) return;
    try {
      await widget.appApi.recordMonetizationAction(
        sessionId: sessionId,
        restaurantId: restaurant['id'].toString(),
        mealId: meal['id']?.toString(),
        action: action,
      );
    } on AppApiException {
      // Commercial telemetry must never block the consumer journey.
    }
  }

  Future<void> _openRestaurant(Map<String, dynamic> item) async {
    final restaurant =
        (item['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {};
    final slug = restaurant['slug']?.toString();
    if (slug == null) return;
    await _record(item, 'RESTAURANT_OPENED');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RestaurantDetailPage(
          slug: slug,
          storeApi: widget.storeApi,
          strings: widget.strings,
          attribution: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(
            title: widget.strings.t('todayQuestion'),
            subtitle: widget.strings.t('recommendSubtitle'),
          ),
          const SizedBox(height: 20),
          Text('${widget.strings.t('maxBudget')}: ${_budget.round()} TL'),
          Slider(
            value: _budget,
            min: 100,
            max: 2000,
            divisions: 19,
            onChanged: (value) => setState(() => _budget = value),
          ),
          FilledButton.icon(
            onPressed: () => setState(() {
              _recommendations =
                  widget.appApi.recommendations(maxBudget: _budget);
            }),
            icon: const Icon(Icons.auto_awesome),
            label: Text(widget.strings.t('suggest')),
          ),
          const SizedBox(height: 16),
          if (_recommendations != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _recommendations,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const _LoadingCard();
                return Column(
                  children: snapshot.data!.map((item) {
                    final meal =
                        (item['meal'] as Map?)?.cast<String, dynamic>() ??
                            const {};
                    final restaurant =
                        (item['restaurant'] as Map?)?.cast<String, dynamic>() ??
                            const {};
                    final sponsored = item['isSponsored'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (sponsored)
                              const Chip(
                                avatar: Icon(Icons.campaign_outlined, size: 16),
                                label: Text('Sponsored'),
                              ),
                            Text(
                              meal['name']?.toString() ??
                                  widget.strings.t('meal'),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${restaurant['name'] ?? ''} · ${meal['price'] ?? '-'} ${meal['currency'] ?? 'TRY'}',
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _openRestaurant(item),
                                  icon: const Icon(Icons.storefront_outlined),
                                  label: Text(widget.strings.t('restaurantDetail')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => widget.storeApi.addFavorite(
                                    mealId: meal['id']?.toString(),
                                  ),
                                  icon: const Icon(Icons.favorite_border),
                                  label: Text(widget.strings.t('favorite')),
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
      );
}

class _RestaurantDetailPage extends StatefulWidget {
  const _RestaurantDetailPage({
    required this.slug,
    required this.storeApi,
    required this.strings,
    this.attribution,
  });

  final String slug;
  final StoreReadyApi storeApi;
  final AppStrings strings;
  final Map<String, dynamic>? attribution;

  @override
  State<_RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<_RestaurantDetailPage> {
  late final Future<Map<String, dynamic>> _restaurant =
      widget.storeApi.restaurantDetail(widget.slug);

  Future<void> _recordNavigation(Map<String, dynamic> restaurant) async {
    final item = widget.attribution;
    if (item == null || item['_attributionLive'] != true) return;
    final sessionId = item['_recommendationSessionId']?.toString();
    final meal = (item['meal'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (sessionId == null || restaurant['id'] == null) return;
    try {
      await widget.storeApi.appApi.recordMonetizationAction(
        sessionId: sessionId,
        restaurantId: restaurant['id'].toString(),
        mealId: meal['id']?.toString(),
        action: 'NAVIGATION_STARTED',
      );
    } on AppApiException {
      // Navigation remains available even when telemetry is unavailable.
    }
  }

  Future<void> _navigate(Map<String, dynamic> restaurant) async {
    await _recordNavigation(restaurant);
    final lat = restaurant['latitude'];
    final lng = restaurant['longitude'];
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.t('mapFailed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.strings.t('restaurantDetail'))),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _restaurant,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final restaurant = snapshot.data!;
            final categories =
                (restaurant['categories'] as List? ?? const [])
                    .cast<Map<String, dynamic>>();
            final hours = (restaurant['operatingHours'] as List? ?? const [])
                .cast<Map<String, dynamic>>();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  restaurant['name']?.toString() ??
                      widget.strings.t('restaurant'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  restaurant['description']?.toString() ?? '',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _navigate(restaurant),
                      icon: const Icon(Icons.directions),
                      label: Text(widget.strings.t('directions')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.storeApi.addFavorite(
                        restaurantId: restaurant['id'].toString(),
                      ),
                      icon: const Icon(Icons.favorite_border),
                      label: Text(widget.strings.t('favorite')),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  widget.strings.t('hours'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                ...hours.map(
                  (hour) => ListTile(
                    dense: true,
                    title: Text('${hour['dayOfWeek']}'),
                    trailing: Text(
                      hour['isClosed'] == true
                          ? widget.strings.t('closed')
                          : '${hour['opensAt']} – ${hour['closesAt']}',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.strings.t('menu'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (categories.isEmpty)
                  _MessageCard(widget.strings.t('menuEmpty'))
                else
                  ...categories.map((category) {
                    final meals =
                        (category['meals'] as List? ?? const [])
                            .cast<Map<String, dynamic>>();
                    return Card(
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(category['name']?.toString() ?? ''),
                        children: meals
                            .map(
                              (meal) => ListTile(
                                title: Text(meal['name']?.toString() ?? ''),
                                subtitle: Text(
                                  meal['description']?.toString() ?? '',
                                ),
                                trailing: Text(
                                  '${meal['price'] ?? '-'} ${meal['currency'] ?? ''}',
                                ),
                              ),
                            )
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

class _FavoritesPage extends StatefulWidget {
  const _FavoritesPage({
    required this.appApi,
    required this.storeApi,
    required this.strings,
  });

  final AppApi appApi;
  final StoreReadyApi storeApi;
  final AppStrings strings;

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  late Future<List<Map<String, dynamic>>> _favorites =
      widget.appApi.favorites();

  void _reload() => setState(() => _favorites = widget.appApi.favorites());

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(
            title: widget.strings.t('favoritesTitle'),
            subtitle: widget.strings.t('favoritesSubtitle'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _favorites,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const _LoadingCard();
              if (snapshot.data!.isEmpty) {
                return _MessageCard(widget.strings.t('favoritesEmpty'));
              }
              return Column(
                children: snapshot.data!.map((item) {
                  final restaurant = item['restaurant'] as Map<String, dynamic>?;
                  final meal = item['meal'] as Map<String, dynamic>?;
                  return Card(
                    child: ListTile(
                      title: Text(
                        (meal?['name'] ?? restaurant?['name'] ?? '').toString(),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await widget.storeApi
                              .removeFavorite(item['id'].toString());
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
      );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.controller,
    required this.strings,
    required this.language,
    required this.onLanguageChanged,
    required this.onSync,
  });

  final AuthSessionController controller;
  final AppStrings strings;
  final String language;
  final Future<void> Function(String) onLanguageChanged;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(
            title: strings.t('account'),
            subtitle: strings.t('accountSubtitle'),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                controller.session?.user.displayName ?? strings.t('user'),
              ),
              subtitle: Text(controller.session?.user.email ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: InputDecoration(
              labelText: strings.t('language'),
              border: const OutlineInputBorder(),
            ),
            items: AppStrings.supportedCodes
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(AppStrings.languageNames[code]!),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onLanguageChanged(value);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync),
            label: Text(strings.t('syncNow')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout),
            label: Text(strings.t('logout')),
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
          Text(
            title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
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
  const _MessageCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(message),
        ),
      );
}

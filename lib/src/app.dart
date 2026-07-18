import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/food_catalog.dart';
import 'domain/food.dart';
import 'localization/app_localizations.dart';
import 'presentation/revenue_hub_page.dart';
import 'services/decision_engine.dart';

class DecidooApp extends StatefulWidget {
  const DecidooApp({super.key});

  @override
  State<DecidooApp> createState() => _DecidooAppState();
}

class _DecidooAppState extends State<DecidooApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Decidoo',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (_locale != null) return _locale;
        if (deviceLocale == null) return const Locale('en');
        return supportedLocales.firstWhere(
          (locale) => locale.languageCode == deviceLocale.languageCode,
          orElse: () => const Locale('en'),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5A36)),
        scaffoldBackgroundColor: const Color(0xFFF8F7F4),
        cardTheme: const CardThemeData(elevation: 0),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      home: DecidooShell(
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}

class DecidooShell extends StatefulWidget {
  const DecidooShell({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<DecidooShell> createState() => _DecidooShellState();
}

class _DecidooShellState extends State<DecidooShell> {
  final DecisionEngine _engine = DecisionEngine();
  final List<DecisionResult> _history = [];
  final Set<String> _favorites = {};
  var _tab = 0;
  var _goal = FoodGoal.surpriseMe;
  var _price = PriceLevel.standard;
  var _meal = MealMoment.dinner;
  DecisionResult? _result;

  void _decide() {
    final result = _engine.decide(
      foodCatalog,
      DecisionRequest(
        goal: _goal,
        priceLevel: _price,
        mealMoment: _meal,
        previousFoodIds: _history.take(5).map((item) => item.food.id).toSet(),
      ),
    );
    setState(() {
      _result = result;
      _history.insert(0, result);
    });
  }

  void _showLanguagePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLocalizations.supportedLocales
              .map(
                (locale) => ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(AppLocalizations(locale).languageName),
                  onTap: () {
                    widget.onLocaleChanged(locale);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = [
      _DecisionPage(
        goal: _goal,
        price: _price,
        meal: _meal,
        result: _result,
        favorite: _result != null && _favorites.contains(_result!.food.id),
        onGoalChanged: (value) => setState(() => _goal = value),
        onPriceChanged: (value) => setState(() => _price = value),
        onMealChanged: (value) => setState(() => _meal = value),
        onDecide: _decide,
        onLanguage: _showLanguagePicker,
        onFavorite: () {
          final id = _result?.food.id;
          if (id == null) return;
          setState(() => _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id));
        },
      ),
      _ExplorePage(favorites: _favorites),
      _HistoryPage(history: _history),
      const RevenueHubPage(),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: l10n.t('decision'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.t('explore'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.t('history'),
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Revenue',
          ),
        ],
      ),
    );
  }
}

class _DecisionPage extends StatelessWidget {
  const _DecisionPage({
    required this.goal,
    required this.price,
    required this.meal,
    required this.result,
    required this.favorite,
    required this.onGoalChanged,
    required this.onPriceChanged,
    required this.onMealChanged,
    required this.onDecide,
    required this.onLanguage,
    required this.onFavorite,
  });

  final FoodGoal goal;
  final PriceLevel price;
  final MealMoment meal;
  final DecisionResult? result;
  final bool favorite;
  final ValueChanged<FoodGoal> onGoalChanged;
  final ValueChanged<PriceLevel> onPriceChanged;
  final ValueChanged<MealMoment> onMealChanged;
  final VoidCallback onDecide;
  final VoidCallback onLanguage;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('decidoo', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text(l10n.t('tagline'), style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            IconButton.filledTonal(onPressed: onLanguage, icon: const Icon(Icons.language_rounded)),
          ],
        ),
        const SizedBox(height: 24),
        _Hero(title: l10n.t('today'), subtitle: l10n.t('heroSubtitle')),
        const SizedBox(height: 24),
        _Selector<FoodGoal>(title: l10n.t('goalTitle'), value: goal, values: FoodGoal.values, label: (value) => _goalLabel(l10n, value), onChanged: onGoalChanged),
        const SizedBox(height: 18),
        _Selector<PriceLevel>(title: l10n.t('budget'), value: price, values: PriceLevel.values, label: (value) => _priceLabel(l10n, value), onChanged: onPriceChanged),
        const SizedBox(height: 18),
        _Selector<MealMoment>(title: l10n.t('meal'), value: meal, values: MealMoment.values, label: (value) => _mealLabel(l10n, value), onChanged: onMealChanged),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: onDecide, icon: const Icon(Icons.bolt_rounded), label: Text(l10n.t('decide'))),
        if (result != null) ...[
          const SizedBox(height: 20),
          _ResultCard(result: result!, favorite: favorite, onFavorite: onFavorite, onAgain: onDecide),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF241915), Color(0xFF5D2B1F)]),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

class _Selector<T> extends StatelessWidget {
  const _Selector({required this.title, required this.value, required this.values, required this.label, required this.onChanged});
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((item) => ChoiceChip(label: Text(label(item)), selected: value == item, onSelected: (_) => onChanged(item))).toList(),
          ),
        ],
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.favorite, required this.onFavorite, required this.onAgain});
  final DecisionResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(result.food.emoji, style: const TextStyle(fontSize: 48)), const Spacer(), IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.favorite : Icons.favorite_border))]),
            Text(result.food.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${result.food.cuisine} • ${result.food.estimatedMinutes} ${l10n.t('minutes')} • %${(result.confidence * 100).round()} ${l10n.t('match')}'),
            const SizedBox(height: 12),
            Text(result.food.description),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onAgain, icon: const Icon(Icons.refresh), label: Text(l10n.t('again'))),
          ],
        ),
      ),
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.favorites});
  final Set<String> favorites;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.t('explore'), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...foodCatalog.map((food) => Card(child: ListTile(leading: Text(food.emoji, style: const TextStyle(fontSize: 30)), title: Text(food.name), subtitle: Text(food.cuisine), trailing: Icon(favorites.contains(food.id) ? Icons.favorite : Icons.chevron_right)))),
      ],
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.history});
  final List<DecisionResult> history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.t('history'), style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        if (history.isEmpty) Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: Text(l10n.t('emptyHistory')))) else ...history.map((item) => Card(child: ListTile(leading: Text(item.food.emoji), title: Text(item.food.name), subtitle: Text('%${(item.confidence * 100).round()} ${l10n.t('match')}')))),
      ],
    );
  }
}

String _goalLabel(AppLocalizations l10n, FoodGoal value) => switch (value) {
      FoodGoal.surpriseMe => l10n.t('surprise'),
      FoodGoal.light => l10n.t('light'),
      FoodGoal.filling => l10n.t('filling'),
      FoodGoal.healthy => l10n.t('healthy'),
      FoodGoal.comfort => l10n.t('comfort'),
    };

String _priceLabel(AppLocalizations l10n, PriceLevel value) => switch (value) {
      PriceLevel.budget => l10n.t('budgetLow'),
      PriceLevel.standard => l10n.t('standard'),
      PriceLevel.premium => l10n.t('premium'),
    };

String _mealLabel(AppLocalizations l10n, MealMoment value) => switch (value) {
      MealMoment.breakfast => l10n.t('breakfast'),
      MealMoment.lunch => l10n.t('lunch'),
      MealMoment.dinner => l10n.t('dinner'),
      MealMoment.lateNight => l10n.t('lateNight'),
    };

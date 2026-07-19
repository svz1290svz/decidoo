import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/food_catalog.dart';
import 'domain/food.dart';
import 'localization/app_localizations.dart';
import 'services/decision_engine.dart';

const _ink = Color(0xFF070A16);
const _panel = Color(0xFF101426);
const _panelSoft = Color(0xFF171B31);
const _orange = Color(0xFFFF6B35);
const _violet = Color(0xFF725CFF);
const _muted = Color(0xFF9DA3BA);

class DecidooApp extends StatefulWidget {
  const DecidooApp({super.key});

  @override
  State<DecidooApp> createState() => _DecidooAppState();
}

class _DecidooAppState extends State<DecidooApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _orange,
      brightness: Brightness.dark,
      surface: _panel,
    );
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
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _ink,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          color: _panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: _panel,
          indicatorColor: Color(0x33FF6B35),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

  void _toggleFavorite(String id) {
    setState(() {
      _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    });
  }

  void _showLanguagePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
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
          if (id != null) _toggleFavorite(id);
        },
      ),
      _ExplorePage(favorites: _favorites, onFavorite: _toggleFavorite),
      _HistoryPage(history: _history),
      const _RevenuePage(),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-.7, -.9),
          radius: 1.25,
          colors: [Color(0x553A25A8), _ink],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome, color: _orange),
              label: l10n.t('decision'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore, color: _orange),
              label: l10n.t('explore'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_rounded),
              selectedIcon: const Icon(Icons.history_rounded, color: _orange),
              label: l10n.t('history'),
            ),
            const NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded, color: _orange),
              label: 'Revenue',
            ),
          ],
        ),
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
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        Row(
          children: [
            const _Brand(),
            const Spacer(),
            _RoundIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
            const SizedBox(width: 8),
            _RoundIcon(icon: Icons.language_rounded, onTap: onLanguage),
          ],
        ),
        const SizedBox(height: 24),
        _HeroPanel(
          title: isTr ? 'Karar verme.\nDecidoo’ya bırak.' : 'Stop deciding.\nLet Decidoo choose.',
          subtitle: isTr
              ? 'Tek dokunuşla sana özel yemek önerisi.'
              : 'One tap. One personalized meal decision.',
          onDecide: onDecide,
        ),
        const SizedBox(height: 24),
        Text(
          isTr ? 'Bugün ne istiyorsun?' : 'What do you want today?',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        _ChoiceSection<FoodGoal>(
          value: goal,
          values: FoodGoal.values,
          icon: _goalIcon,
          label: (value) => _goalLabel(l10n, value),
          onChanged: onGoalChanged,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _CompactSelector<PriceLevel>(
                title: l10n.t('budget'),
                value: price,
                values: PriceLevel.values,
                label: (value) => _priceLabel(l10n, value),
                onChanged: onPriceChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompactSelector<MealMoment>(
                title: l10n.t('meal'),
                value: meal,
                values: MealMoment.values,
                label: (value) => _mealLabel(l10n, value),
                onChanged: onMealChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('decide-button'),
          onPressed: onDecide,
          icon: const Icon(Icons.auto_awesome),
          label: Text(isTr ? 'BUGÜN NE YİYECEĞİM?' : 'WHAT SHOULD I EAT TODAY?'),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(animation), child: child),
          ),
          child: result == null
              ? _EmptyDecision(key: const ValueKey('empty'), isTr: isTr)
              : _ResultCard(
                  key: ValueKey(result!.food.id),
                  result: result!,
                  favorite: favorite,
                  onFavorite: onFavorite,
                  onAgain: onDecide,
                ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.8),
          children: [
            TextSpan(text: 'DECID', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'OO', style: TextStyle(color: _orange)),
          ],
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 21),
        style: IconButton.styleFrom(backgroundColor: _panelSoft),
      );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.title, required this.subtitle, required this.onDecide});
  final String title;
  final String subtitle;
  final VoidCallback onDecide;

  @override
  Widget build(BuildContext context) => Container(
        height: 275,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C246A), Color(0xFF12162C), Color(0xFF331829)],
          ),
          border: Border.all(color: const Color(0x44725CFF)),
          boxShadow: const [BoxShadow(color: Color(0x332F23A8), blurRadius: 35, offset: Offset(0, 18))],
        ),
        child: Stack(
          children: [
            const Positioned(right: -20, top: 10, child: _GlowOrb(size: 120, color: _violet)),
            const Positioned(right: 38, bottom: 26, child: _GlowOrb(size: 70, color: _orange)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Chip(
                  avatar: Icon(Icons.auto_awesome, color: _orange, size: 17),
                  label: Text('AI DECISION ENGINE'),
                  side: BorderSide(color: Color(0x33725CFF)),
                  backgroundColor: Color(0x22101426),
                ),
                const Spacer(),
                Text(title, style: const TextStyle(fontSize: 31, height: 1.04, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                Text(subtitle, style: const TextStyle(color: _muted, height: 1.35)),
                const SizedBox(height: 18),
                SizedBox(
                  width: 160,
                  child: FilledButton.tonalIcon(
                    onPressed: onDecide,
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('DECIDE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)]),
        ),
      );
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({required this.value, required this.values, required this.icon, required this.label, required this.onChanged});
  final T value;
  final List<T> values;
  final IconData Function(T) icon;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 105,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = values[index];
            final selected = item == value;
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 104,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x33FF6B35) : _panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: selected ? _orange : const Color(0x221FFFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon(item), color: selected ? _orange : _muted),
                    const Spacer(),
                    Text(label(item), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : _muted)),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _CompactSelector<T> extends StatelessWidget {
  const _CompactSelector({required this.title, required this.value, required this.values, required this.label, required this.onChanged});
  final String title;
  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 11, 12, 7),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x221FFFFFFF))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            dropdownColor: _panelSoft,
            borderRadius: BorderRadius.circular(18),
            items: values.map((item) => DropdownMenuItem(value: item, child: Text(label(item), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (item) {
              if (item != null) onChanged(item);
            },
            selectedItemBuilder: (context) => values
                .map((item) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: _muted, fontSize: 11)), Text(label(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))]))
                .toList(),
          ),
        ),
      );
}

class _EmptyDecision extends StatelessWidget {
  const _EmptyDecision({super.key, required this.isTr});
  final bool isTr;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _panel.withValues(alpha: .75), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x221FFFFFFF))),
        child: Row(
          children: [
            const Icon(Icons.touch_app_rounded, color: _orange, size: 34),
            const SizedBox(width: 14),
            Expanded(child: Text(isTr ? 'Tercihlerini seç ve Decidoo’nun senin için karar vermesine izin ver.' : 'Set your preferences and let Decidoo make the decision for you.', style: const TextStyle(color: _muted, height: 1.35))),
          ],
        ),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.result, required this.favorite, required this.onFavorite, required this.onAgain});
  final DecisionResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF1D213B), Color(0xFF13172A)]),
        border: Border.all(color: const Color(0x55FF6B35)),
        boxShadow: const [BoxShadow(color: Color(0x22FF6B35), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 68, height: 68, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x22FF6B35), borderRadius: BorderRadius.circular(20)), child: Text(result.food.emoji, style: const TextStyle(fontSize: 40))),
              const Spacer(),
              IconButton.filledTonal(onPressed: onFavorite, icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: _orange)),
            ],
          ),
          const SizedBox(height: 16),
          Text(result.food.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${result.food.cuisine}  •  ${result.food.estimatedMinutes} ${l10n.t('minutes')}', style: const TextStyle(color: _muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: result.confidence, minHeight: 9, backgroundColor: const Color(0x221FFFFFFF), color: _orange))),
              const SizedBox(width: 12),
              Text('%${(result.confidence * 100).round()}', style: const TextStyle(color: _orange, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Text(result.food.description, style: const TextStyle(color: Color(0xFFD3D6E2), height: 1.4)),
          const SizedBox(height: 12),
          ...result.reasons.take(3).map((reason) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [const Icon(Icons.check_circle_rounded, color: _orange, size: 17), const SizedBox(width: 8), Expanded(child: Text(reason, style: const TextStyle(color: _muted)))]))),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onAgain, icon: const Icon(Icons.refresh_rounded), label: Text(l10n.t('again'))),
        ],
      ),
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.favorites, required this.onFavorite});
  final Set<String> favorites;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        const _Brand(),
        const SizedBox(height: 22),
        Text(l10n.t('explore'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        Text(isTr ? 'Dünyanın lezzetlerini keşfet.' : 'Discover flavors from around the world.', style: const TextStyle(color: _muted)),
        const SizedBox(height: 20),
        ...foodCatalog.map(
          (food) => Container(
            margin: const EdgeInsets.only(bottom: 13),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x221FFFFFFF))),
            child: Row(
              children: [
                Container(width: 62, height: 62, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0x333A25A8), Color(0x33FF6B35)]), borderRadius: BorderRadius.circular(19)), child: Text(food.emoji, style: const TextStyle(fontSize: 35))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(food.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${food.cuisine} • ${food.estimatedMinutes} ${l10n.t('minutes')}', style: const TextStyle(color: _muted))])),
                IconButton(onPressed: () => onFavorite(food.id), icon: Icon(favorites.contains(food.id) ? Icons.favorite : Icons.favorite_border, color: favorites.contains(food.id) ? _orange : _muted)),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        const _Brand(),
        const SizedBox(height: 22),
        Text(l10n.t('history'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 22),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(28)),
            child: Column(children: [const Icon(Icons.history_toggle_off_rounded, size: 54, color: _muted), const SizedBox(height: 14), Text(l10n.t('emptyHistory'), textAlign: TextAlign.center, style: const TextStyle(color: _muted))]),
          )
        else
          ...history.map((item) => Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: Text(item.food.emoji, style: const TextStyle(fontSize: 32)), title: Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${item.food.cuisine} • %${(item.confidence * 100).round()} ${l10n.t('match')}', style: const TextStyle(color: _muted)), trailing: const Icon(Icons.chevron_right_rounded, color: _orange)))),
      ],
    );
  }
}

class _RevenuePage extends StatelessWidget {
  const _RevenuePage();

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    const plans = [
      ('FREE', 'USD 0', 'Core decisions • Sponsored offers'),
      ('PREMIUM', 'USD 6.99', 'No ads • Unlimited history • Advanced AI'),
      ('RESTAURANT PRO', 'USD 49', 'Analytics • Campaigns • Menu insights'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        const _Brand(),
        const SizedBox(height: 22),
        Text('Revenue Hub', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        Text(isTr ? 'Global büyüme ve gelir altyapısı.' : 'Global growth and monetization infrastructure.', style: const TextStyle(color: _muted)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF302267), Color(0xFF4A1C31)]), borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0x44725CFF))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.workspace_premium_rounded, color: _orange, size: 38), const SizedBox(height: 14), Text(isTr ? 'Decidoo Premium' : 'Decidoo Premium', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(isTr ? 'Daha güçlü kişiselleştirme, reklamsız kararlar ve sınırsız geçmiş.' : 'Stronger personalization, ad-free decisions and unlimited history.', style: const TextStyle(color: Color(0xFFD1D4E1), height: 1.4))]),
        ),
        const SizedBox(height: 18),
        ...plans.map((plan) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: plan.$1 == 'PREMIUM' ? _orange : const Color(0x221FFFFFFF))), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(plan.$1, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(plan.$3, style: const TextStyle(color: _muted, fontSize: 12))])), Text(plan.$2, style: TextStyle(color: plan.$1 == 'PREMIUM' ? _orange : Colors.white, fontWeight: FontWeight.w900))]))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isTr ? 'Güvenli mağaza ödeme bağlantısı yayın hesabıyla etkinleştirilecek.' : 'Secure store billing will activate with production accounts.'))), icon: const Icon(Icons.lock_outline_rounded), label: Text(isTr ? 'GÜVENLİ ÖDEME' : 'SECURE PAYMENT')),
        const SizedBox(height: 24),
        Text(isTr ? '7 gelir kanalı' : '7 revenue channels', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('Premium')), Chip(label: Text('Restaurant SaaS')), Chip(label: Text('Commission')), Chip(label: Text('Sponsored')), Chip(label: Text('Corporate')), Chip(label: Text('API')), Chip(label: Text('Analytics'))]),
      ],
    );
  }
}

IconData _goalIcon(FoodGoal value) => switch (value) {
      FoodGoal.surpriseMe => Icons.auto_awesome,
      FoodGoal.light => Icons.eco_outlined,
      FoodGoal.filling => Icons.lunch_dining_rounded,
      FoodGoal.healthy => Icons.favorite_outline_rounded,
      FoodGoal.comfort => Icons.soup_kitchen_outlined,
    };

String _goalLabel(AppLocalizations l10n, FoodGoal value) => switch (value) {
      FoodGoal.surpriseMe => l10n.t('surprise'),
      FoodGoal.light => l10n.t('light'),
      FoodGoal.filling => l10n.t('filling'),
      FoodGoal.healthy => l10n.t('healthy'),
      FoodGoal.comfort => l10n.t('comfort'),
    };

String _priceLabel(AppLocalizations l10n, PriceLevel value) => switch (value) {
      PriceLevel.budget => l10n.t('budgetFriendly'),
      PriceLevel.standard => l10n.t('standard'),
      PriceLevel.premium => l10n.t('premium'),
    };

String _mealLabel(AppLocalizations l10n, MealMoment value) => switch (value) {
      MealMoment.breakfast => l10n.t('breakfast'),
      MealMoment.lunch => l10n.t('lunch'),
      MealMoment.dinner => l10n.t('dinner'),
      MealMoment.lateNight => l10n.t('lateNight'),
    };

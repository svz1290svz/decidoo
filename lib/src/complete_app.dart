import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/food_catalog.dart';
import 'domain/food.dart';
import 'localization/app_localizations.dart';
import 'services/decision_engine.dart';

const _bg = Color(0xFF070A16);
const _panel = Color(0xFF11162A);
const _panel2 = Color(0xFF191F38);
const _orange = Color(0xFFFF6B35);
const _violet = Color(0xFF755CFF);
const _muted = Color(0xFFA7ADC2);

class CompleteDecidooApp extends StatefulWidget {
  const CompleteDecidooApp({super.key});

  @override
  State<CompleteDecidooApp> createState() => _CompleteDecidooAppState();
}

class _CompleteDecidooAppState extends State<CompleteDecidooApp> {
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _orange,
          brightness: Brightness.dark,
          surface: _panel,
        ),
        cardTheme: CardThemeData(
          color: _panel,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: _RootFlow(onLocaleChanged: (value) => setState(() => _locale = value)),
    );
  }
}

class _RootFlow extends StatefulWidget {
  const _RootFlow({required this.onLocaleChanged});
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<_RootFlow> {
  var _stage = 0;

  @override
  Widget build(BuildContext context) {
    final child = switch (_stage) {
      0 => _Onboarding(onContinue: () => setState(() => _stage = 1)),
      1 => _Login(onContinue: () => setState(() => _stage = 2)),
      _ => _MainShell(onLocaleChanged: widget.onLocaleChanged),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_stage), child: child),
    );
  }
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _controller = PageController();
  var _page = 0;

  static const _items = [
    ('Stop overthinking.', 'Decidoo turns endless food choices into one confident decision.', Icons.auto_awesome_rounded),
    ('Made for you.', 'Your mood, budget, meal time and history shape every result.', Icons.tune_rounded),
    ('Discover globally.', 'Explore dishes, save favorites and build a taste profile over time.', Icons.public_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(-.6, -.8), radius: 1.3, colors: [Color(0x663F2AA8), _bg]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(24), child: Align(alignment: Alignment.centerLeft, child: _Brand())),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: .75, end: 1),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.elasticOut,
                            builder: (_, value, child) => Transform.scale(scale: value, child: child),
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [_violet, _orange]),
                                boxShadow: const [BoxShadow(color: Color(0x55755CFF), blurRadius: 55)],
                              ),
                              child: Icon(item.$3, size: 78),
                            ),
                          ),
                          const SizedBox(height: 42),
                          Text(item.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 16),
                          Text(item.$2, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 17, height: 1.45)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_items.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.all(4), width: index == _page ? 28 : 8, height: 8, decoration: BoxDecoration(color: index == _page ? _orange : Colors.white24, borderRadius: BorderRadius.circular(20))))),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () {
                        if (_page == _items.length - 1) {
                          widget.onContinue();
                        } else {
                          _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                        }
                      },
                      child: Text(_page == _items.length - 1 ? 'GET STARTED' : 'CONTINUE'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Login extends StatelessWidget {
  const _Login({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const _Brand(),
            const SizedBox(height: 54),
            const Text('Welcome to your\nsmart food life.', style: TextStyle(fontSize: 38, height: 1.05, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            const Text('Sign in to sync favorites, decisions and your taste profile.', style: TextStyle(color: _muted, fontSize: 16, height: 1.45)),
            const SizedBox(height: 34),
            TextField(decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.mail_outline_rounded), filled: true, fillColor: _panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
            const SizedBox(height: 14),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), filled: true, fillColor: _panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            FilledButton(onPressed: onContinue, child: const Text('SIGN IN')),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onContinue, icon: const Icon(Icons.g_mobiledata_rounded), label: const Text('Continue with Google')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onContinue, icon: const Icon(Icons.apple_rounded), label: const Text('Continue with Apple')),
            const SizedBox(height: 24),
            TextButton(onPressed: onContinue, child: const Text('Continue as guest')),
          ],
        ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({required this.onLocaleChanged});
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  final _engine = DecisionEngine();
  final _history = <DecisionResult>[];
  final _favorites = <String>{};
  var _tab = 0;
  var _goal = FoodGoal.surpriseMe;
  var _price = PriceLevel.standard;
  var _meal = MealMoment.dinner;
  DecisionResult? _result;

  void _decide() {
    final value = _engine.decide(foodCatalog, DecisionRequest(goal: _goal, priceLevel: _price, mealMoment: _meal, previousFoodIds: _history.take(5).map((e) => e.food.id).toSet()));
    setState(() {
      _result = value;
      _history.insert(0, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Home(goal: _goal, price: _price, meal: _meal, result: _result, onGoal: (v) => setState(() => _goal = v), onPrice: (v) => setState(() => _price = v), onMeal: (v) => setState(() => _meal = v), onDecide: _decide, onFavorite: () { final id = _result?.food.id; if (id != null) setState(() => _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id)); }, favorite: _result != null && _favorites.contains(_result!.food.id)),
      _Explore(favorites: _favorites, onToggle: (id) => setState(() => _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id))),
      _Saved(favorites: _favorites),
      _History(history: _history),
      _Profile(onLocaleChanged: widget.onLocaleChanged),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(animation), child: child)),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: _panel,
        indicatorColor: const Color(0x33FF6B35),
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome, color: _orange), label: 'Decide'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore, color: _orange), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite, color: _orange), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded, color: _orange), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: _orange), label: 'Profile'),
        ],
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.goal, required this.price, required this.meal, required this.result, required this.onGoal, required this.onPrice, required this.onMeal, required this.onDecide, required this.onFavorite, required this.favorite});
  final FoodGoal goal;
  final PriceLevel price;
  final MealMoment meal;
  final DecisionResult? result;
  final ValueChanged<FoodGoal> onGoal;
  final ValueChanged<PriceLevel> onPrice;
  final ValueChanged<MealMoment> onMeal;
  final VoidCallback onDecide;
  final VoidCallback onFavorite;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const Row(children: [_Brand(), Spacer(), CircleAvatar(backgroundColor: _panel2, child: Icon(Icons.notifications_none_rounded))]),
          const SizedBox(height: 24),
          _HeroCard(onDecide: onDecide),
          const SizedBox(height: 26),
          const Text('How do you want to feel?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, children: FoodGoal.values.map((item) => _GoalCard(selected: goal == item, label: item.name, onTap: () => onGoal(item))).toList())),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: _Dropdown<PriceLevel>(title: 'Budget', value: price, values: PriceLevel.values, onChanged: onPrice)), const SizedBox(width: 12), Expanded(child: _Dropdown<MealMoment>(title: 'Meal', value: meal, values: MealMoment.values, onChanged: onMeal))]),
          const SizedBox(height: 20),
          FilledButton.icon(key: const Key('complete-decide-button'), onPressed: onDecide, icon: const Icon(Icons.bolt_rounded), label: const Text('LET DECIDOO CHOOSE')),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)), child: child)),
            child: result == null ? const _EmptyResult(key: ValueKey('empty')) : _DecisionCard(key: ValueKey(result!.food.id), result: result!, favorite: favorite, onFavorite: onFavorite),
          ),
        ],
      ),
    );
  }
}

class _Explore extends StatelessWidget {
  const _Explore({required this.favorites, required this.onToggle});
  final Set<String> favorites;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Explore', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Global dishes selected for curious appetites.', style: TextStyle(color: _muted)),
      const SizedBox(height: 20),
      TextField(decoration: InputDecoration(hintText: 'Search dishes or cuisines', prefixIcon: const Icon(Icons.search), filled: true, fillColor: _panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
      const SizedBox(height: 18),
      ...foodCatalog.map((food) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _FoodTile(food: food, favorite: favorites.contains(food.id), onFavorite: () => onToggle(food.id)))),
    ]));
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.favorites});
  final Set<String> favorites;

  @override
  Widget build(BuildContext context) {
    final items = foodCatalog.where((food) => favorites.contains(food.id)).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Saved', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      if (items.isEmpty) const _CenteredEmpty(icon: Icons.favorite_outline, title: 'No favorites yet', subtitle: 'Save dishes from decisions or Explore.') else ...items.map((food) => _FoodTile(food: food, favorite: true, onFavorite: () {})),
    ]));
  }
}

class _History extends StatelessWidget {
  const _History({required this.history});
  final List<DecisionResult> history;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Decision history', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      if (history.isEmpty) const _CenteredEmpty(icon: Icons.history_rounded, title: 'Your story starts here', subtitle: 'Every recommendation will appear here.') else ...history.map((item) => Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: Text(item.food.emoji, style: const TextStyle(fontSize: 34)), title: Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${(item.confidence * 100).round()}% match • ${item.food.cuisine}'))),
    ]));
  }
}

class _Profile extends StatefulWidget {
  const _Profile({required this.onLocaleChanged});
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  var _notifications = true;
  var _personalization = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Profile', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        Container(width: 72, height: 72, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_violet, _orange])), child: const Icon(Icons.person_rounded, size: 40)),
        const SizedBox(width: 16),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Decidoo Explorer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Free plan • 12 decisions', style: TextStyle(color: _muted))])),
        IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
      ]))),
      const SizedBox(height: 16),
      _PremiumBanner(),
      const SizedBox(height: 18),
      const Text('Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Card(child: Column(children: [
        SwitchListTile(value: _notifications, onChanged: (v) => setState(() => _notifications = v), title: const Text('Smart notifications'), subtitle: const Text('Meal-time reminders and discovery alerts')),
        const Divider(height: 1),
        SwitchListTile(value: _personalization, onChanged: (v) => setState(() => _personalization = v), title: const Text('Personalized decisions'), subtitle: const Text('Use history to improve recommendations')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.language_rounded), title: const Text('Language'), trailing: const Icon(Icons.chevron_right), onTap: () => showModalBottomSheet<void>(context: context, backgroundColor: _panel, showDragHandle: true, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: AppLocalizations.supportedLocales.map((locale) => ListTile(title: Text(AppLocalizations(locale).languageName), onTap: () { widget.onLocaleChanged(locale); Navigator.pop(context); })).toList())))),
        const Divider(height: 1),
        const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Privacy & data'), trailing: Icon(Icons.chevron_right)),
        const Divider(height: 1),
        const ListTile(leading: Icon(Icons.help_outline_rounded), title: Text('Help & support'), trailing: Icon(Icons.chevron_right)),
      ])),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out')),
      const SizedBox(height: 12),
      const Center(child: Text('Decidoo 2.0.0 • Made for global appetites', style: TextStyle(color: _muted, fontSize: 12))),
    ]));
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onDecide});
  final VoidCallback onDecide;

  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF342977), Color(0xFF14182E), Color(0xFF3B1D2C)]), boxShadow: const [BoxShadow(color: Color(0x443B2BB0), blurRadius: 42, offset: Offset(0, 20))]),
    child: Stack(children: [
      const Positioned(right: -25, top: -15, child: _Orb(size: 150, color: _violet)),
      const Positioned(right: 35, bottom: -5, child: _Orb(size: 90, color: _orange)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Chip(label: Text('AI DECISION ENGINE'), avatar: Icon(Icons.auto_awesome, color: _orange, size: 17), backgroundColor: Color(0x22000000)),
        const Spacer(),
        const Text('One tap.\nOne great decision.', style: TextStyle(fontSize: 31, height: 1.02, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        SizedBox(width: 150, child: FilledButton.tonalIcon(onPressed: onDecide, icon: const Icon(Icons.bolt_rounded), label: const Text('DECIDE'))),
      ]),
    ]),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.selected, required this.label, required this.onTap});
  final bool selected;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: AnimatedContainer(duration: const Duration(milliseconds: 250), width: 105, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: selected ? const Color(0x333E2BFF) : _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: selected ? _violet : Colors.white10)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(selected ? Icons.auto_awesome : Icons.circle_outlined, color: selected ? _orange : _muted), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]))));
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.title, required this.value, required this.values, required this.onChanged});
  final String title;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(16, 8, 12, 8), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20)), child: DropdownButtonHideUnderline(child: DropdownButton<T>(isExpanded: true, value: value, items: values.map((item) => DropdownMenuItem(value: item, child: Text('$title\n${item.toString().split('.').last}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(), onChanged: (item) { if (item != null) onChanged(item); })));
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({super.key, required this.result, required this.favorite, required this.onFavorite});
  final DecisionResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Text(result.food.emoji, style: const TextStyle(fontSize: 56)), const Spacer(), IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? _orange : null))]),
    Text(result.food.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text('${result.food.cuisine} • ${result.food.estimatedMinutes} min', style: const TextStyle(color: _muted)),
    const SizedBox(height: 14),
    LinearProgressIndicator(value: result.confidence, minHeight: 8, borderRadius: BorderRadius.circular(20), color: _orange, backgroundColor: Colors.white10),
    const SizedBox(height: 8),
    Text('${(result.confidence * 100).round()}% personal match', style: const TextStyle(fontWeight: FontWeight.w800)),
    const SizedBox(height: 14),
    Text(result.food.description, style: const TextStyle(color: _muted, height: 1.4)),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: () => _showFoodDetails(context, result.food), icon: const Icon(Icons.restaurant_menu_rounded), label: const Text('VIEW DETAILS')),
  ])));
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.favorite, required this.onFavorite});
  final Food food;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(26), onTap: () => _showFoodDetails(context, food), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(width: 70, height: 70, alignment: Alignment.center, decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(20)), child: Text(food.emoji, style: const TextStyle(fontSize: 38))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(food.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('${food.cuisine} • ${food.estimatedMinutes} min', style: const TextStyle(color: _muted)), const SizedBox(height: 5), Text(food.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted))])), IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? _orange : null))]))));
}

void _showFoodDetails(BuildContext context, Food food) {
  showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: _panel, showDragHandle: true, builder: (_) => FractionallySizedBox(heightFactor: .82, child: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 32), children: [
    Center(child: Text(food.emoji, style: const TextStyle(fontSize: 100))),
    const SizedBox(height: 10),
    Text(food.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text('${food.cuisine} • ${food.estimatedMinutes} min • ${food.priceLevel.name}', style: const TextStyle(color: _muted)),
    const SizedBox(height: 22),
    Text(food.description, style: const TextStyle(fontSize: 16, height: 1.5)),
    const SizedBox(height: 24),
    const Text('Why Decidoo recommends it', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    ...food.tags.map((tag) => ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(backgroundColor: Color(0x33FF6B35), child: Icon(Icons.check, color: _orange)), title: Text(tag))),
    const SizedBox(height: 18),
    FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.navigation_rounded), label: const Text('FIND NEARBY')),
  ])));
}

class _PremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [_violet, _orange])), child: const Row(children: [Icon(Icons.workspace_premium_rounded, size: 40), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Unlock Decidoo Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Unlimited decisions, advanced personalization and no sponsored content.', style: TextStyle(fontSize: 12))])), Icon(Icons.chevron_right)]));
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white10)), child: const Row(children: [CircleAvatar(radius: 28, backgroundColor: _panel2, child: Icon(Icons.auto_awesome, color: _orange)), SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ready when you are', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), SizedBox(height: 4), Text('Set your preferences and let Decidoo choose.', style: TextStyle(color: _muted))]))]));
}

class _CenteredEmpty extends StatelessWidget {
  const _CenteredEmpty({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 120), child: Column(children: [Icon(icon, size: 64, color: _muted), const SizedBox(height: 18), Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted))]));
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => RichText(text: const TextSpan(style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.7), children: [TextSpan(text: 'DECID'), TextSpan(text: 'OO', style: TextStyle(color: _orange))]));
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)])));
}

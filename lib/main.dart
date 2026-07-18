import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const DecidooApp());

class DecidooApp extends StatelessWidget {
  const DecidooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Decidoo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBF7),
        useMaterial3: true,
      ),
      home: const DecisionPage(),
    );
  }
}

class DecisionPage extends StatefulWidget {
  const DecisionPage({super.key});

  @override
  State<DecisionPage> createState() => _DecisionPageState();
}

class _DecisionPageState extends State<DecisionPage> {
  final RecommendationEngine _engine = RecommendationEngine();

  String _mood = 'Fark etmez';
  String _budget = 'Orta';
  String _mealTime = 'Akşam';
  FoodRecommendation? _recommendation;

  static const moods = ['Fark etmez', 'Hafif', 'Doyurucu', 'Sağlıklı'];
  static const budgets = ['Ekonomik', 'Orta', 'Premium'];
  static const mealTimes = ['Kahvaltı', 'Öğle', 'Akşam', 'Gece'];

  void _decide() {
    setState(() {
      _recommendation = _engine.recommend(
        mood: _mood,
        budget: _budget,
        mealTime: _mealTime,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              children: [
                const Text(
                  'decidoo',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bugün ne yiyeceğine Decidoo karar versin.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 34),
                ChoiceSection(
                  title: 'Nasıl bir şey istiyorsun?',
                  values: moods,
                  selected: _mood,
                  onSelected: (value) => setState(() => _mood = value),
                ),
                const SizedBox(height: 24),
                ChoiceSection(
                  title: 'Bütçen?',
                  values: budgets,
                  selected: _budget,
                  onSelected: (value) => setState(() => _budget = value),
                ),
                const SizedBox(height: 24),
                ChoiceSection(
                  title: 'Hangi öğün?',
                  values: mealTimes,
                  selected: _mealTime,
                  onSelected: (value) => setState(() => _mealTime = value),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _decide,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Benim için karar ver',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_recommendation != null) ...[
                  const SizedBox(height: 28),
                  RecommendationCard(recommendation: _recommendation!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChoiceSection extends StatelessWidget {
  const ChoiceSection({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
  });

  final FoodRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recommendation.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              recommendation.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(recommendation.reason),
          ],
        ),
      ),
    );
  }
}

class FoodRecommendation {
  const FoodRecommendation({
    required this.name,
    required this.emoji,
    required this.reason,
    required this.moods,
    required this.budgets,
    required this.mealTimes,
  });

  final String name;
  final String emoji;
  final String reason;
  final List<String> moods;
  final List<String> budgets;
  final List<String> mealTimes;
}

class RecommendationEngine {
  final Random _random = Random();

  final List<FoodRecommendation> _foods = const [
    FoodRecommendation(
      name: 'Menemen',
      emoji: '🍳',
      reason: 'Sıcak, hızlı ve güne güçlü başlatan bir seçim.',
      moods: ['Fark etmez', 'Doyurucu'],
      budgets: ['Ekonomik', 'Orta'],
      mealTimes: ['Kahvaltı'],
    ),
    FoodRecommendation(
      name: 'Tavuk dürüm',
      emoji: '🌯',
      reason: 'Hızlı, doyurucu ve bütçe dostu bir seçim.',
      moods: ['Fark etmez', 'Doyurucu'],
      budgets: ['Ekonomik', 'Orta'],
      mealTimes: ['Öğle', 'Akşam', 'Gece'],
    ),
    FoodRecommendation(
      name: 'Izgara tavuk salata',
      emoji: '🥗',
      reason: 'Hafif kalırken tok tutan dengeli bir seçenek.',
      moods: ['Fark etmez', 'Hafif', 'Sağlıklı'],
      budgets: ['Orta', 'Premium'],
      mealTimes: ['Öğle', 'Akşam'],
    ),
    FoodRecommendation(
      name: 'Burger',
      emoji: '🍔',
      reason: 'Bugün güçlü ve keyifli bir lezzet iyi gider.',
      moods: ['Fark etmez', 'Doyurucu'],
      budgets: ['Orta', 'Premium'],
      mealTimes: ['Öğle', 'Akşam', 'Gece'],
    ),
    FoodRecommendation(
      name: 'Mercimek çorbası',
      emoji: '🥣',
      reason: 'Hafif, ekonomik ve rahatlatıcı bir tercih.',
      moods: ['Fark etmez', 'Hafif', 'Sağlıklı'],
      budgets: ['Ekonomik', 'Orta'],
      mealTimes: ['Öğle', 'Akşam', 'Gece'],
    ),
    FoodRecommendation(
      name: 'Somon ve sebze',
      emoji: '🐟',
      reason: 'Sağlıklı ve premium bir akşam seçimi.',
      moods: ['Sağlıklı', 'Hafif'],
      budgets: ['Premium'],
      mealTimes: ['Akşam'],
    ),
  ];

  FoodRecommendation recommend({
    required String mood,
    required String budget,
    required String mealTime,
  }) {
    final matches = _foods.where((food) {
      return food.moods.contains(mood) &&
          food.budgets.contains(budget) &&
          food.mealTimes.contains(mealTime);
    }).toList();

    final pool = matches.isEmpty
        ? _foods.where((food) => food.mealTimes.contains(mealTime)).toList()
        : matches;

    final safePool = pool.isEmpty ? _foods : pool;
    return safePool[_random.nextInt(safePool.length)];
  }
}

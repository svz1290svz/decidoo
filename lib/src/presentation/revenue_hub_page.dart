import 'package:flutter/material.dart';

import '../domain/monetization.dart';
import '../services/monetization_service.dart';

class RevenueHubPage extends StatefulWidget {
  const RevenueHubPage({super.key});

  @override
  State<RevenueHubPage> createState() => _RevenueHubPageState();
}

class _RevenueHubPageState extends State<RevenueHubPage> {
  ConsumerPlan _consumerPlan = ConsumerPlan.free;
  String? _selectedRestaurantPlan;

  @override
  Widget build(BuildContext context) {
    final isTurkish = Localizations.localeOf(context).languageCode == 'tr';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      children: [
        Text(
          isTurkish ? 'Gelir Merkezi' : 'Revenue Hub',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          isTurkish
              ? 'Premium, restoran paketleri ve ticari büyüme altyapısı.'
              : 'Premium, restaurant plans and commercial growth infrastructure.',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        _SectionTitle(isTurkish ? 'Kullanıcı planları' : 'Consumer plans'),
        const SizedBox(height: 12),
        ...MonetizationService.consumerPlans.map(
          (plan) => _PlanCard(
            plan: plan,
            selected: _consumerPlan.name == plan.id.split('_').last,
            onTap: () => setState(() {
              _consumerPlan = plan.id.endsWith('premium')
                  ? ConsumerPlan.premium
                  : ConsumerPlan.free;
            }),
          ),
        ),
        const SizedBox(height: 26),
        _SectionTitle(isTurkish ? 'Restoran paketleri' : 'Restaurant plans'),
        const SizedBox(height: 12),
        ...MonetizationService.restaurantPlans.map(
          (plan) => _PlanCard(
            plan: plan,
            selected: _selectedRestaurantPlan == plan.id,
            onTap: () => setState(() => _selectedRestaurantPlan = plan.id),
          ),
        ),
        const SizedBox(height: 26),
        _SectionTitle(isTurkish ? '7 gelir kanalı' : '7 revenue channels'),
        const SizedBox(height: 12),
        const _RevenueChannelsGrid(),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isTurkish
                      ? 'Ödeme sağlayıcısı bağlandığında satın alma burada başlayacak.'
                      : 'Purchase flow will start here after a payment provider is connected.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.lock_outline_rounded),
          label: Text(isTurkish ? 'Güvenli ödemeye geç' : 'Continue to secure payment'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PricingPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.title,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (plan.recommended)
                            const Chip(label: Text('Popular')),
                        ],
                      ),
                      Text('${plan.price.formatted} / month'),
                      const SizedBox(height: 8),
                      ...plan.features.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $item'),
                        ),
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

class _RevenueChannelsGrid extends StatelessWidget {
  const _RevenueChannelsGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Premium', Icons.workspace_premium_outlined),
      ('Restaurant SaaS', Icons.storefront_outlined),
      ('Commission', Icons.receipt_long_outlined),
      ('Sponsored', Icons.campaign_outlined),
      ('Corporate', Icons.business_outlined),
      ('API', Icons.api_outlined),
      ('Analytics', Icons.analytics_outlined),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => Chip(
              avatar: Icon(item.$2, size: 18),
              label: Text(item.$1),
            ),
          )
          .toList(),
    );
  }
}

import '../domain/monetization.dart';

class MonetizationService {
  const MonetizationService();

  static final consumerPlans = <PricingPlan>[
    PricingPlan(
      id: 'consumer_free',
      title: 'Free',
      price: Money(0, 'usd'),
      features: const ['Core decisions', 'Limited history', 'Sponsored offers'],
      channel: RevenueChannel.consumerSubscription,
    ),
    PricingPlan(
      id: 'consumer_premium',
      title: 'Decidoo Premium',
      price: Money(6.99, 'usd'),
      features: const [
        'Ad-free decisions',
        'Diet and allergy controls',
        'Unlimited history',
        'Advanced personalization',
      ],
      channel: RevenueChannel.consumerSubscription,
      recommended: true,
    ),
  ];

  static final restaurantPlans = <PricingPlan>[
    PricingPlan(
      id: 'restaurant_free',
      title: 'Restaurant Free',
      price: Money(0, 'usd'),
      features: const ['Basic listing', 'Menu profile'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_starter',
      title: 'Starter',
      price: Money(19, 'usd'),
      features: const ['Verified listing', 'Basic analytics', 'Campaign tools'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_pro',
      title: 'Pro',
      price: Money(49, 'usd'),
      features: const ['Advanced analytics', 'Priority campaigns', 'Menu insights'],
      channel: RevenueChannel.restaurantSubscription,
      recommended: true,
    ),
    PricingPlan(
      id: 'restaurant_premium',
      title: 'Premium',
      price: Money(99, 'usd'),
      features: const ['Multi-branch tools', 'AI recommendations', 'Attribution'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_enterprise',
      title: 'Enterprise',
      price: Money(299, 'usd'),
      features: const ['Custom limits', 'Dedicated support', 'API access'],
      channel: RevenueChannel.restaurantSubscription,
    ),
  ];

  double commissionFor(double grossOrderValue, {double rate = 0.035}) {
    if (!grossOrderValue.isFinite || grossOrderValue < 0) {
      throw ArgumentError.value(grossOrderValue, 'grossOrderValue');
    }
    if (!rate.isFinite || rate < 0 || rate > 1) {
      throw ArgumentError.value(rate, 'rate');
    }
    return grossOrderValue * rate;
  }

  SponsoredPlacement? chooseSponsoredPlacement(
    List<SponsoredPlacement> placements, {
    required String settlementCurrency,
  }) {
    final currency = settlementCurrency.trim().toLowerCase();
    final eligible = placements
        .where(
          (item) => item.isEligible && item.bid.currency == currency,
        )
        .toList()
      ..sort((a, b) => b.bid.amount.compareTo(a.bid.amount));
    return eligible.isEmpty ? null : eligible.first;
  }

  bool canShowSponsoredContent({
    required ConsumerPlan plan,
    required bool consentGranted,
  }) {
    return plan == ConsumerPlan.free && consentGranted;
  }
}

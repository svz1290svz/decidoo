import '../domain/monetization.dart';

class MonetizationService {
  const MonetizationService();

  static const consumerPlans = <PricingPlan>[
    PricingPlan(
      id: 'consumer_free',
      title: 'Free',
      price: Money(0, 'usd'),
      features: ['Core decisions', 'Limited history', 'Sponsored offers'],
      channel: RevenueChannel.consumerSubscription,
    ),
    PricingPlan(
      id: 'consumer_premium',
      title: 'Decidoo Premium',
      price: Money(6.99, 'usd'),
      features: [
        'Ad-free decisions',
        'Diet and allergy controls',
        'Unlimited history',
        'Advanced personalization',
      ],
      channel: RevenueChannel.consumerSubscription,
      recommended: true,
    ),
  ];

  static const restaurantPlans = <PricingPlan>[
    PricingPlan(
      id: 'restaurant_free',
      title: 'Restaurant Free',
      price: Money(0, 'usd'),
      features: ['Basic listing', 'Menu profile'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_starter',
      title: 'Starter',
      price: Money(19, 'usd'),
      features: ['Verified listing', 'Basic analytics', 'Campaign tools'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_pro',
      title: 'Pro',
      price: Money(49, 'usd'),
      features: ['Advanced analytics', 'Priority campaigns', 'Menu insights'],
      channel: RevenueChannel.restaurantSubscription,
      recommended: true,
    ),
    PricingPlan(
      id: 'restaurant_premium',
      title: 'Premium',
      price: Money(99, 'usd'),
      features: ['Multi-branch tools', 'AI recommendations', 'Attribution'],
      channel: RevenueChannel.restaurantSubscription,
    ),
    PricingPlan(
      id: 'restaurant_enterprise',
      title: 'Enterprise',
      price: Money(299, 'usd'),
      features: ['Custom limits', 'Dedicated support', 'API access'],
      channel: RevenueChannel.restaurantSubscription,
    ),
  ];

  double commissionFor(double grossOrderValue, {double rate = 0.035}) {
    if (grossOrderValue < 0) {
      throw ArgumentError.value(grossOrderValue, 'grossOrderValue');
    }
    if (rate < 0 || rate > 1) {
      throw ArgumentError.value(rate, 'rate');
    }
    return grossOrderValue * rate;
  }

  SponsoredPlacement? chooseSponsoredPlacement(
    List<SponsoredPlacement> placements,
  ) {
    final eligible = placements.where((item) => item.isEligible).toList()
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

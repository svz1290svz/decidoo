enum ConsumerPlan { free, premium }

enum RestaurantPlan { free, starter, pro, premium, enterprise }

enum RevenueChannel {
  consumerSubscription,
  restaurantSubscription,
  transactionCommission,
  sponsoredRecommendation,
  corporateLicense,
  apiUsage,
  analyticsInsights,
}

class Money {
  Money(double amount, String currency)
      : amount = _validateAmount(amount),
        currency = _validateCurrency(currency);

  final double amount;
  final String currency;

  static double _validateAmount(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'amount', 'Must be finite and non-negative.');
    }
    return value;
  }

  static String _validateCurrency(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z]{3}$').hasMatch(normalized)) {
      throw ArgumentError.value(value, 'currency', 'Must be a 3-letter ISO code.');
    }
    return normalized;
  }

  String get formatted => '${currency.toUpperCase()} ${amount.toStringAsFixed(2)}';
}

class PricingPlan {
  const PricingPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.features,
    required this.channel,
    this.recommended = false,
  });

  final String id;
  final String title;
  final Money price;
  final List<String> features;
  final RevenueChannel channel;
  final bool recommended;
}

class SponsoredPlacement {
  const SponsoredPlacement({
    required this.campaignId,
    required this.restaurantId,
    required this.label,
    required this.bid,
    required this.isEligible,
  });

  final String campaignId;
  final String restaurantId;
  final String label;
  final Money bid;
  final bool isEligible;
}

class RevenueEvent {
  const RevenueEvent({
    required this.channel,
    required this.eventName,
    required this.occurredAt,
    this.value,
    this.metadata = const {},
  });

  final RevenueChannel channel;
  final String eventName;
  final DateTime occurredAt;
  final Money? value;
  final Map<String, String> metadata;
}

import 'package:decidoo/src/domain/monetization.dart';
import 'package:decidoo/src/services/monetization_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MonetizationService();

  group('MonetizationService', () {
    test('calculates transaction commission', () {
      expect(service.commissionFor(100), closeTo(3.5, .001));
      expect(service.commissionFor(100, rate: .05), closeTo(5, .001));
    });

    test('rejects invalid commission input', () {
      expect(() => service.commissionFor(-1), throwsArgumentError);
      expect(() => service.commissionFor(double.nan), throwsArgumentError);
      expect(() => service.commissionFor(double.infinity), throwsArgumentError);
      expect(() => service.commissionFor(10, rate: 1.1), throwsArgumentError);
      expect(
        () => service.commissionFor(10, rate: double.nan),
        throwsArgumentError,
      );
    });

    test('money rejects invalid values and currency codes', () {
      expect(() => Money(-1, 'usd'), throwsArgumentError);
      expect(() => Money(double.nan, 'usd'), throwsArgumentError);
      expect(() => Money(double.infinity, 'usd'), throwsArgumentError);
      expect(() => Money(1, 'dollar'), throwsArgumentError);
      expect(Money(1, ' USD ').currency, 'usd');
    });

    test('premium users never receive sponsored content', () {
      expect(
        service.canShowSponsoredContent(
          plan: ConsumerPlan.premium,
          consentGranted: true,
        ),
        isFalse,
      );
    });

    test('free users require consent for sponsored content', () {
      expect(
        service.canShowSponsoredContent(
          plan: ConsumerPlan.free,
          consentGranted: false,
        ),
        isFalse,
      );
      expect(
        service.canShowSponsoredContent(
          plan: ConsumerPlan.free,
          consentGranted: true,
        ),
        isTrue,
      );
    });

    test('chooses highest eligible bid in settlement currency only', () {
      final result = service.chooseSponsoredPlacement(
        [
          SponsoredPlacement(
            campaignId: 'a',
            restaurantId: 'r1',
            label: 'Sponsored',
            bid: Money(1, 'usd'),
            isEligible: true,
          ),
          SponsoredPlacement(
            campaignId: 'b',
            restaurantId: 'r2',
            label: 'Sponsored',
            bid: Money(3, 'usd'),
            isEligible: true,
          ),
          SponsoredPlacement(
            campaignId: 'c',
            restaurantId: 'r3',
            label: 'Sponsored',
            bid: Money(10, 'eur'),
            isEligible: true,
          ),
          SponsoredPlacement(
            campaignId: 'd',
            restaurantId: 'r4',
            label: 'Sponsored',
            bid: Money(20, 'usd'),
            isEligible: false,
          ),
        ],
        settlementCurrency: 'USD',
      );

      expect(result?.campaignId, 'b');
    });

    test('returns null when no eligible campaign uses settlement currency', () {
      final result = service.chooseSponsoredPlacement(
        [
          SponsoredPlacement(
            campaignId: 'eur-only',
            restaurantId: 'r1',
            label: 'Sponsored',
            bid: Money(5, 'eur'),
            isEligible: true,
          ),
        ],
        settlementCurrency: 'usd',
      );

      expect(result, isNull);
    });
  });
}

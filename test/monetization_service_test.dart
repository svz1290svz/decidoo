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
      expect(() => service.commissionFor(10, rate: 1.1), throwsArgumentError);
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

    test('chooses highest eligible sponsored bid', () {
      final result = service.chooseSponsoredPlacement(const [
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
          bid: Money(10, 'usd'),
          isEligible: false,
        ),
      ]);

      expect(result?.campaignId, 'b');
    });
  });
}

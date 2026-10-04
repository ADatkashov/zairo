import 'package:business_admin/features/loyalty/data/models/loyalty_birthday.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoyaltyBirthday.fromJson reads the backend shape', () {
    final b = LoyaltyBirthday.fromJson({
      'userId': 'u1',
      'displayName': 'Aigerim',
      'month': 4,
      'day': 23,
      'daysUntil': 0,
      'bonusPoints': 100,
      'bonusAwarded': true,
      'greetedToday': true,
    });

    expect(b.userId, 'u1');
    expect(b.displayName, 'Aigerim');
    expect((b.month, b.day, b.daysUntil), (4, 23, 0));
    expect(b.bonusPoints, 100);
    expect(b.bonusAwarded, isTrue);
    expect(b.greetedToday, isTrue);
  });

  test('LoyaltySettings reads birthdayBonusPoints, defaulting to 0 when absent', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
          'providerId': 'p1',
          'enabled': true,
          'name': 'Rewards',
          'fixedPointsPerBooking': 10,
          'pointsPerCurrencyUnit': 0,
          'firstBookingBonusPoints': 0,
          'repeatVisitBonusPoints': 0,
          'repeatVisitThreshold': 2,
          'reviewBonusPoints': 0,
          'pointsExpireEnabled': false,
          ...extra,
        };

    expect(LoyaltySettings.fromJson(json({'birthdayBonusPoints': 150})).birthdayBonusPoints, 150);
    expect(LoyaltySettings.fromJson(json({})).birthdayBonusPoints, 0);
    expect(LoyaltySettings.fromJson(json({'birthdayBonusPoints': 150})).toUpdateJson()['birthdayBonusPoints'], 150);
  });
}

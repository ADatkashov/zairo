import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';

void main() {
  test('fromJson reads the personal profile fields', () {
    final user = UserSummary.fromJson({
      'id': 'u1',
      'email': 'a@example.com',
      'displayName': 'Aigerim',
      'role': 'CUSTOMER',
      'birthDate': '1995-04-23',
      'gender': 'FEMALE',
      'marketingConsent': true,
    });

    expect(user.birthDate, DateTime(1995, 4, 23));
    expect(user.gender, 'FEMALE');
    expect(user.marketingConsent, isTrue);
  });

  test('fromJson defaults the personal fields when the backend omits them', () {
    final user = UserSummary.fromJson({
      'id': 'u1',
      'email': null,
      'displayName': 'Aigerim',
      'role': 'CUSTOMER',
    });

    expect(user.birthDate, isNull);
    expect(user.gender, isNull);
    expect(user.marketingConsent, isFalse);
  });

  test('formatBirthDate pads and round-trips with parseBirthDate', () {
    final date = DateTime(2001, 2, 3);

    expect(UserSummary.formatBirthDate(date), '2001-02-03');
    expect(UserSummary.parseBirthDate('2001-02-03'), date);
  });
}

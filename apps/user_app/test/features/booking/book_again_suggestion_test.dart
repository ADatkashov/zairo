import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/book_again_suggestion.dart';

Map<String, dynamic> _json({String? nextFreeAt}) => {
  'providerId': 'p1',
  'providerName': 'Studio',
  'vertical': 'beauty',
  'serviceId': 's1',
  'serviceTitle': 'Haircut',
  'durationMinutes': 30,
  'price': 25,
  'currency': 'USD',
  'lastVisitAt': '2026-08-01T13:30:00Z',
  'nextFreeAt': nextFreeAt,
};

void main() {
  test('parses the next free time when the provider has one', () {
    final s = BookAgainSuggestion.fromJson(_json(nextFreeAt: '2026-08-20T09:00:00Z'));
    expect(s.nextFreeAt, DateTime.utc(2026, 8, 20, 9));
  });

  test('a provider with nothing open has no next free time', () {
    expect(BookAgainSuggestion.fromJson(_json()).nextFreeAt, isNull);
  });
}

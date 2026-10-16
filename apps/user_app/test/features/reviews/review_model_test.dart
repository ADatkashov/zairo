import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/reviews/data/models/review.dart';

void main() {
  test('Review reads the separate rating of the person, null when absent', () {
    final base = {
      'id': 'r1',
      'bookingId': 'b1',
      'rating': 5,
      'createdAt': '2026-10-15T10:00:00Z',
    };

    expect(Review.fromJson({...base, 'workerRating': 3}).workerRating, 3);
    expect(Review.fromJson(base).workerRating, isNull);
  });
}

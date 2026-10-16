import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/staff/data/models/staff_cabinet.dart';

void main() {
  test('a membership reads its business, state and rating, which may be absent', () {
    final full = StaffMembership.fromJson({
      'staffId': 's1',
      'providerId': 'p1',
      'providerName': 'Glow Salon',
      'displayName': 'Aigerim',
      'photoUrl': 'https://cdn.example/a.jpg',
      'active': true,
      'pendingCount': 2,
      'averageRating': 4.5,
      'reviewCount': 8,
    });
    expect(full.providerName, 'Glow Salon');
    expect(full.photoUrl, 'https://cdn.example/a.jpg');
    expect(full.pendingCount, 2);
    expect(full.averageRating, 4.5);

    final fresh = StaffMembership.fromJson({
      'staffId': 's2',
      'providerId': 'p2',
      'providerName': 'Clinic',
      'displayName': 'Dana',
      'active': false,
      'pendingCount': 0,
      'reviewCount': 0,
    });
    expect(fresh.photoUrl, isNull);
    expect(fresh.averageRating, isNull);
    expect(fresh.active, isFalse);
  });

  test('an appointment reads its amounts, times and what the person may do with it', () {
    final accepted = StaffAppointment.fromJson({
      'bookingId': 'b1',
      'status': 'CONFIRMED',
      'startsAt': '2026-10-20T10:00:00Z',
      'endsAt': '2026-10-20T11:00:00Z',
      'serviceTitle': 'Haircut',
      'customerName': 'Aisha',
      'customerPhone': '+7000',
      'totalPrice': 8000,
      'currency': 'KZT',
      'paidAmount': 3000.5,
      'staffConfirmedAt': '2026-10-19T09:00:00Z',
      'canAccept': false,
      'canDecline': true,
      'canComplete': true,
      'canMarkNoShow': false,
    });
    expect(accepted.startsAt, DateTime.utc(2026, 10, 20, 10));
    expect(accepted.totalPrice, 8000.0);
    expect(accepted.paidAmount, 3000.5);
    expect(accepted.staffConfirmedAt, DateTime.utc(2026, 10, 19, 9));
    expect(accepted.staffDeclinedAt, isNull);
    expect([accepted.canAccept, accepted.canDecline, accepted.canComplete, accepted.canMarkNoShow], [
      false,
      true,
      true,
      false,
    ]);

    final declined = StaffAppointment.fromJson({
      'bookingId': 'b2',
      'status': 'CANCELLED',
      'startsAt': '2026-10-21T10:00:00Z',
      'endsAt': '2026-10-21T11:00:00Z',
      'totalPrice': 100,
      'currency': 'KZT',
      'paidAmount': 0,
      'cancellationReason': 'Sick',
      'staffDeclinedAt': '2026-10-20T08:00:00Z',
      'canAccept': false,
      'canDecline': false,
      'canComplete': false,
      'canMarkNoShow': false,
    });
    expect(declined.serviceTitle, isNull);
    expect(declined.customerName, isNull);
    expect(declined.cancellationReason, 'Sick');
    expect(declined.staffConfirmedAt, isNull);
    expect(declined.staffDeclinedAt, DateTime.utc(2026, 10, 20, 8));
  });

  test('a rating reads its distribution and reviews, with or without a name, text and reply', () {
    final rating = StaffRating.fromJson({
      'averageRating': 4.5,
      'reviewCount': 2,
      'distribution': [0, 0, 0, 1, 1],
      'reviews': [
        {
          'reviewId': 'r1',
          'bookingId': 'b1',
          'customerName': 'Aisha',
          'rating': 5,
          'comment': 'Great',
          'createdAt': '2026-10-12T10:00:00Z',
          'businessReply': 'Thanks',
        },
        {'reviewId': 'r2', 'bookingId': 'b2', 'rating': 4, 'createdAt': '2026-10-11T10:00:00Z'},
      ],
    });

    expect(rating.averageRating, 4.5);
    expect(rating.distribution, [0, 0, 0, 1, 1]);
    expect(rating.reviews, hasLength(2));
    expect(rating.reviews[0].businessReply, 'Thanks');
    expect(rating.reviews[1].customerName, isNull);
    expect(rating.reviews[1].comment, isNull);
    expect(rating.reviews[1].businessReply, isNull);

    final none = StaffRating.fromJson({'reviewCount': 0, 'distribution': [0, 0, 0, 0, 0], 'reviews': <Object>[]});
    expect(none.averageRating, isNull);
    expect(none.reviews, isEmpty);
  });
}

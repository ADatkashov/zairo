import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/booking.dart';
import 'package:zairo/features/notifications/data/models/app_notification.dart';
import 'package:zairo/app/router/app_routes.dart';
import 'package:zairo/features/notifications/notification_destination.dart';
import 'package:zairo/features/notifications/notification_text.dart';
import 'package:zairo/l10n/app_localizations.dart';

const _id = '3f2b8c1e-5a4d-4e7b-9c10-2d6f8a1b7e90';

AppNotification _n(String type, String title, String body) => AppNotification(
  id: 'n',
  type: type,
  title: title,
  body: body,
  read: false,
  createdAt: DateTime(2026, 10, 24, 9),
);

final _booking = Booking(
  id: _id,
  userId: 'u',
  serviceId: 's',
  availabilitySlotId: 'a',
  status: 'CONFIRMED',
  totalPrice: 1000,
  createdAt: DateTime(2026, 10, 20),
  serviceTitle: 'Haircut',
  providerName: 'Salon X',
  startsAt: DateTime(2026, 10, 24, 15),
);

Future<AppLocalizations> _l10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  test('finds the booking id the backend wrote into the sentence', () {
    expect(
      notificationBookingId(
        _n(
          'BOOKING_CONFIRMED',
          'Booking confirmed',
          'Your booking ($_id) is confirmed.',
        ),
      ),
      _id,
    );
    expect(
      notificationBookingId(_n('GREETING', 'Hi', 'Happy birthday!')),
      isNull,
    );
  });

  test('a booking event reads as service, business and time — no id', () async {
    final l10n = await _l10n('en');
    final text = presentNotification(
      l10n,
      _n(
        'BOOKING_CONFIRMED',
        'Booking confirmed',
        'Your booking ($_id) is confirmed.',
      ),
      booking: _booking,
    );
    expect(text.title, 'Booking confirmed');
    expect(
      text.body,
      "Haircut · Salon X · Oct 24, 15:00\nWe'll see you there!",
    );
    expect(text.body, isNot(contains(_id)));
  });

  test('without the booking it still has no id, just the short line', () async {
    final l10n = await _l10n('en');
    final text = presentNotification(
      l10n,
      _n(
        'BOOKING_CANCELLED',
        'Booking cancelled',
        'Your booking ($_id) has been cancelled.',
      ),
    );
    expect(text.title, 'Booking cancelled');
    expect(text.body, 'This booking has been cancelled.');
  });

  test('a booking missing every detail falls back to the short line', () async {
    final l10n = await _l10n('en');
    final bare = Booking(
      id: _id,
      userId: 'u',
      serviceId: 's',
      availabilitySlotId: 'a',
      status: 'CONFIRMED',
      totalPrice: 1,
      createdAt: DateTime(2026, 10, 20),
    );
    final text = presentNotification(
      l10n,
      _n('PAYMENT_REFUNDED', 'Refund processed', 'Your refund ($_id)'),
      booking: bare,
    );
    expect(text.title, 'Refund processed');
    expect(text.body, 'Your money is on its way back to you.');
  });

  test(
    'both reminders and the other booking events get their own wording',
    () async {
      final l10n = await _l10n('en');
      String title(String type, [String serverTitle = 'x']) =>
          presentNotification(l10n, _n(type, serverTitle, 'b ($_id)')).title;
      expect(
        title('BOOKING_REMINDER', 'Upcoming booking reminder'),
        'Your visit is in about 2 hours',
      );
      expect(
        title('BOOKING_REMINDER', 'Your visit is coming up'),
        'Your visit is coming up',
      );
      expect(title('BOOKING_MOVED'), 'Your appointment was moved');
      expect(title('CHANGE_REQUESTED'), 'Please choose how to proceed');
      expect(title('WORKER_CHANGED'), 'Your specialist has changed');
    },
  );

  test('is translated into Russian and Kazakh', () async {
    final ru = presentNotification(
      await _l10n('ru'),
      _n(
        'BOOKING_CONFIRMED',
        'Booking confirmed',
        'Your booking ($_id) is confirmed.',
      ),
    );
    expect(ru.title, 'Запись подтверждена');
    final kk = presentNotification(
      await _l10n('kk'),
      _n(
        'BOOKING_CONFIRMED',
        'Booking confirmed',
        'Your booking ($_id) is confirmed.',
      ),
    );
    expect(kk.title, 'Жазылу расталды');
  });

  test(
    'offers and greetings keep the business wording but lose any id',
    () async {
      final l10n = await _l10n('en');
      final text = presentNotification(
        l10n,
        _n(
          'GREETING',
          'A greeting from Salon X',
          'Salon X wishes you well ($_id)  today',
        ),
      );
      expect(text.title, 'A greeting from Salon X');
      expect(text.body, 'Salon X wishes you well today');
      expect(
        presentNotification(
          l10n,
          _n('REBOOK_OFFER', 'Time?', 'Ready to book?'),
        ).body,
        'Ready to book?',
      );
    },
  );

  test('moved / specialist events open Bookings, where the person acts', () {
    for (final type in [
      'BOOKING_MOVED',
      'CHANGE_REQUESTED',
      'WORKER_CHANGED',
    ]) {
      expect(notificationDestination(type), AppRoutes.bookings);
    }
  });
}

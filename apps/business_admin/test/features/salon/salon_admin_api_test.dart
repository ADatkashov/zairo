import 'package:business_admin/features/billing/data/billing_exception.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/models/business_analytics.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _provider = {
  'id': 'p1',
  'ownerUserId': 'o1',
  'name': 'Glow Salon',
  'vertical': 'beauty',
  'status': 'ACTIVE',
  'latitude': 43.2,
  'longitude': 76.9,
  'coverPhotoUrl': 'https://img/cover.png',
  'cityCode': 'almaty',
  'businessTypeId': 'bt1',
};

const _service = {
  'id': 's1',
  'providerId': 'p1',
  'title': 'Haircut',
  'durationMinutes': 60,
  'price': 5000,
  'currency': 'KZT',
  'active': true,
  'catalogServiceId': 'c1',
};

const _slot = {
  'id': 'sl1',
  'providerId': 'p1',
  'startsAt': '2026-10-12T10:00:00Z',
  'endsAt': '2026-10-12T11:00:00Z',
  'status': 'OPEN',
};

const _booking = {
  'id': 'b1',
  'userId': 'u1',
  'serviceId': 's1',
  'availabilitySlotId': 'sl1',
  'status': 'CONFIRMED',
  'totalPrice': 5000,
  'createdAt': '2026-10-01T09:00:00Z',
};

Future<BillingException> _billing(Future<Object?> Function() call) async {
  try {
    await call();
  } on BillingException catch (e) {
    return e;
  }
  fail('expected a BillingException');
}

void main() {
  late FakeHttp http;
  late SalonAdminApi api;

  setUp(() {
    http = FakeHttp();
    api = SalonAdminApi(http.client());
  });

  group('deposit settings', () {
    test('getDepositPercentage maps the payment policy to a percentage', () async {
      http.reply('GET', '/payment-settings', {'depositType': 'FULL_PAYMENT'});
      expect(await api.getDepositPercentage('p1'), 100);
      expect(http.calls('GET', '/payment-settings').single.queryParameters, {'providerId': 'p1'});

      http.reply('GET', '/payment-settings',
          {'depositType': 'DEPOSIT', 'depositValueType': 'PERCENTAGE', 'depositValue': 29.6});
      expect(await api.getDepositPercentage('p1'), 30);

      http.reply('GET', '/payment-settings',
          {'depositType': 'DEPOSIT', 'depositValueType': 'FIXED_AMOUNT', 'depositValue': 1000});
      expect(await api.getDepositPercentage('p1'), 0);

      http.reply('GET', '/payment-settings', {'depositType': 'NO_PAYMENT'});
      expect(await api.getDepositPercentage('p1'), 0);
    });

    test('setDepositPercentage sends no-payment, a percentage deposit, or full payment', () async {
      http.reply('PUT', '/payment-settings', <String, Object?>{});

      await api.setDepositPercentage('p1', 0);
      expect(http.calls('PUT', '/payment-settings').last.data, {'depositType': 'NO_PAYMENT'});

      await api.setDepositPercentage('p1', -5);
      expect(http.calls('PUT', '/payment-settings').last.data, {'depositType': 'NO_PAYMENT'});

      await api.setDepositPercentage('p1', 30);
      expect(http.calls('PUT', '/payment-settings').last.data,
          {'depositType': 'DEPOSIT', 'depositValueType': 'PERCENTAGE', 'depositValue': 30});

      await api.setDepositPercentage('p1', 100);
      expect(http.calls('PUT', '/payment-settings').last.data, {'depositType': 'FULL_PAYMENT'});

      await api.setDepositPercentage('p1', 150);
      expect(http.calls('PUT', '/payment-settings').last.data, {'depositType': 'FULL_PAYMENT'});
      expect(http.calls('PUT', '/payment-settings').last.queryParameters, {'providerId': 'p1'});
    });
  });

  group('providers', () {
    test('listMyProviders parses every field of each provider', () async {
      http.reply('GET', '/users/o1/providers', [_provider]);

      final providers = await api.listMyProviders('o1');

      expect(providers.single.name, 'Glow Salon');
      expect(providers.single.latitude, 43.2);
      expect(providers.single.coverPhotoUrl, 'https://img/cover.png');
      expect(providers.single.cityCode, 'almaty');
      expect(providers.single.businessTypeId, 'bt1');
    });

    test('a provider without the optional fields still parses', () async {
      http.reply('GET', '/users/o1/providers', [
        {'id': 'p2', 'ownerUserId': 'o1', 'name': 'Bare', 'vertical': 'auto', 'status': 'PENDING'},
      ]);

      final provider = (await api.listMyProviders('o1')).single;

      expect(provider.latitude, isNull);
      expect(provider.cityCode, isNull);
    });

    test('createProvider posts the form and maps 402 to "provider limit reached"', () async {
      http.reply('POST', '/providers', _provider);
      final created = await api.createProvider(
        ownerUserId: 'o1',
        name: 'Glow Salon',
        vertical: 'beauty',
        cityCode: 'almaty',
      );
      expect(created.id, 'p1');
      expect(http.bodyOf('POST', '/providers'),
          {'ownerUserId': 'o1', 'name': 'Glow Salon', 'vertical': 'beauty', 'cityCode': 'almaty'});

      http.fail('POST', '/providers', 402);
      final error = await _billing(
          () => api.createProvider(ownerUserId: 'o', name: 'n', vertical: 'v', cityCode: 'c'));
      expect(error.key, SubscriptionErrorKey.providerLimitReached);

      http.fail('POST', '/providers', 500);
      await expectLater(
        api.createProvider(ownerUserId: 'o', name: 'n', vertical: 'v', cityCode: 'c'),
        throwsA(isA<DioException>()),
      );
    });

    test('listProvidersByStatus filters by the status query', () async {
      http.reply('GET', '/providers', [_provider]);
      final result = await api.listProvidersByStatus('PENDING');
      expect(result, hasLength(1));
      expect(http.calls('GET', '/providers').single.queryParameters, {'status': 'PENDING'});
    });

    test('updateProviderStatus patches the status', () async {
      http.reply('PATCH', '/providers/p1/status', _provider);
      await api.updateProviderStatus(providerId: 'p1', status: 'SUSPENDED');
      expect(http.bodyOf('PATCH', '/providers/p1/status'), {'status': 'SUSPENDED'});
    });

    test('updateProvider puts the editable fields, nulls included', () async {
      http.reply('PUT', '/providers/p1', _provider);
      await api.updateProvider(providerId: 'p1', name: 'New name');
      expect(http.bodyOf('PUT', '/providers/p1'),
          {'name': 'New name', 'latitude': null, 'longitude': null, 'coverPhotoUrl': null, 'cityCode': null});
    });

    test('updateProvider sends the public profile only when given', () async {
      http.reply('PUT', '/providers/p1', _provider);
      await api.updateProvider(
        providerId: 'p1',
        name: 'N',
        address: 'Abay 10',
        phone: '',
        description: 'Cosy',
        workingHours: {'mon': '09:00-20:00'},
      );
      final body = http.bodyOf('PUT', '/providers/p1');
      expect(body['address'], 'Abay 10');
      expect(body['phone'], '');
      expect(body['description'], 'Cosy');
      expect(body['workingHours'], {'mon': '09:00-20:00'});
    });

    test('the provider parses its public profile', () {
      final p = AdminProvider.fromJson({
        ..._provider,
        'address': 'Abay 10',
        'phone': '+7',
        'description': 'D',
        'workingHours': {'tue': '10:00-11:00'},
      });
      expect((p.address, p.phone, p.description), ('Abay 10', '+7', 'D'));
      expect(p.workingHours, {'tue': '10:00-11:00'});
      expect(AdminProvider.fromJson(_provider).workingHours, isEmpty);
    });

    test('updateProvider sends the chosen city', () async {
      http.reply('PUT', '/providers/p1', _provider);
      await api.updateProvider(providerId: 'p1', name: 'New name', cityCode: 'almaty');
      expect(http.bodyOf('PUT', '/providers/p1')['cityCode'], 'almaty');
    });
  });

  group('services', () {
    test('listServices asks for inactive ones only when told to', () async {
      http.reply('GET', '/providers/p1/services', [_service]);

      final services = await api.listServices('p1');
      expect(http.calls('GET', '/providers/p1/services').single.queryParameters, {'includeInactive': false});
      expect(services.single.price, 5000);
      expect(services.single.catalogServiceId, 'c1');

      await api.listServices('p1', includeInactive: true);
      expect(http.calls('GET', '/providers/p1/services').last.queryParameters, {'includeInactive': true});
    });

    test('createService and updateService include the catalog link only when set', () async {
      http
        ..reply('POST', '/providers/p1/services', _service)
        ..reply('PUT', '/services/s1', _service);

      await api.createService(
          providerId: 'p1', title: 'Haircut', durationMinutes: 60, price: 5000, currency: 'KZT');
      expect(http.bodyOf('POST', '/providers/p1/services'),
          {'title': 'Haircut', 'durationMinutes': 60, 'price': 5000.0, 'currency': 'KZT'});

      http.requests.clear();
      await api.createService(
          providerId: 'p1',
          title: 'Haircut',
          durationMinutes: 60,
          price: 5000,
          currency: 'KZT',
          catalogServiceId: 'c1');
      expect(http.bodyOf('POST', '/providers/p1/services')['catalogServiceId'], 'c1');

      await api.updateService(
          serviceId: 's1', title: 'Cut', durationMinutes: 45, price: 4000, currency: 'KZT');
      expect(http.bodyOf('PUT', '/services/s1').containsKey('catalogServiceId'), isFalse);
      expect(http.bodyOf('PUT', '/services/s1')['durationMinutes'], 45);

      http.requests.clear();
      await api.updateService(
          serviceId: 's1',
          title: 'Cut',
          durationMinutes: 45,
          price: 4000,
          currency: 'KZT',
          catalogServiceId: 'c2');
      expect(http.bodyOf('PUT', '/services/s1')['catalogServiceId'], 'c2');
    });

    test('deactivate, reactivate and catalog link use their own endpoints', () async {
      http
        ..reply('DELETE', '/services/s1', <String, Object?>{})
        ..reply('POST', '/services/s1/reactivate', _service)
        ..reply('PATCH', '/services/s1/catalog-link', _service);

      await api.deactivateService('s1');
      expect(http.calls('DELETE', '/services/s1'), hasLength(1));

      expect((await api.reactivateService('s1')).active, isTrue);

      await api.linkCatalogService(serviceId: 's1', catalogServiceId: null);
      expect(http.bodyOf('PATCH', '/services/s1/catalog-link'), {'catalogServiceId': null});
    });
  });

  group('availability slots', () {
    test('listSlots parses the slots', () async {
      http.reply('GET', '/providers/p1/availability-slots', [_slot]);
      final slots = await api.listSlots('p1');
      expect(slots.single.status, 'OPEN');
      expect(slots.single.startsAt.toUtc(), DateTime.utc(2026, 10, 12, 10));
    });

    test('createSlot sends UTC timestamps; deleteSlot deletes by id', () async {
      http
        ..reply('POST', '/providers/p1/availability-slots', _slot)
        ..reply('DELETE', '/availability-slots/sl1', <String, Object?>{});

      await api.createSlot(
        providerId: 'p1',
        startsAt: DateTime.utc(2026, 10, 12, 10),
        endsAt: DateTime.utc(2026, 10, 12, 11),
      );
      expect(http.bodyOf('POST', '/providers/p1/availability-slots'),
          {'startsAt': '2026-10-12T10:00:00.000Z', 'endsAt': '2026-10-12T11:00:00.000Z'});

      await api.deleteSlot('sl1');
      expect(http.calls('DELETE', '/availability-slots/sl1'), hasLength(1));
    });

    test('createRecurringSchedule names the weekdays, pads times and dates, and reports the outcome', () async {
      http.reply('POST', '/providers/p1/availability-slots/recurring', {
        'created': [_slot, _slot],
        'skippedConflictCount': 3,
      });

      final result = await api.createRecurringSchedule(
        providerId: 'p1',
        daysOfWeek: [1, 3, 7],
        startHour: 9,
        startMinute: 5,
        endHour: 18,
        endMinute: 0,
        slotDurationMinutes: 60,
        breakMinutes: 15,
        rangeStart: DateTime(2026, 1, 5),
        rangeEnd: DateTime(2026, 12, 31),
        holidays: [DateTime(2026, 3, 9)],
      );

      final body = http.bodyOf('POST', '/providers/p1/availability-slots/recurring');
      expect(body['daysOfWeek'], ['MONDAY', 'WEDNESDAY', 'SUNDAY']);
      expect(body['startTime'], '09:05:00');
      expect(body['endTime'], '18:00:00');
      expect(body['slotDurationMinutes'], 60);
      expect(body['breakMinutes'], 15);
      expect(body['rangeStart'], '2026-01-05');
      expect(body['rangeEnd'], '2026-12-31');
      expect(body['holidays'], ['2026-03-09']);
      expect(body['zoneId'], matches(RegExp(r'^[+-]\d{2}:\d{2}$')));
      expect(result.createdCount, 2);
      expect(result.skippedConflictCount, 3);
    });

    test('createRecurringSchedule maps 402 to "requires upgrade" and rethrows other errors', () async {
      Future<Object?> call() => api.createRecurringSchedule(
            providerId: 'p1',
            daysOfWeek: [1],
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 0,
            slotDurationMinutes: 30,
            breakMinutes: 0,
            rangeStart: DateTime(2026, 1, 1),
            rangeEnd: DateTime(2026, 1, 2),
          );

      http.fail('POST', '/providers/p1/availability-slots/recurring', 402);
      expect((await _billing(call)).key, SubscriptionErrorKey.featureRequiresUpgrade);

      http.fail('POST', '/providers/p1/availability-slots/recurring', 500);
      await expectLater(call(), throwsA(isA<DioException>()));
    });
  });

  group('bookings, schedule and payouts', () {
    test('listBookings and completeBooking parse bookings', () async {
      http
        ..reply('GET', '/providers/p1/bookings', [_booking])
        ..reply('POST', '/bookings/b1/complete', {..._booking, 'status': 'COMPLETED'});

      expect((await api.listBookings('p1')).single.totalPrice, 5000);
      expect((await api.completeBooking('b1')).status, 'COMPLETED');
    });

    test('a cancelled booking carries the reason, an ordinary one has none', () async {
      http.reply('GET', '/providers/p1/bookings', [
        {..._booking, 'status': 'CANCELLED', 'cancellationReason': 'Change of plans'},
        _booking,
      ]);

      final bookings = await api.listBookings('p1');

      expect(bookings[0].cancellationReason, 'Change of plans');
      expect(bookings[1].cancellationReason, isNull);
    });

    test('fetchSchedule sends the window in UTC and parses entries', () async {
      http.reply('GET', '/providers/p1/schedule', [
        {
          'bookingId': 'b1',
          'serviceId': 's1',
          'availabilitySlotId': 'sl1',
          'status': 'CONFIRMED',
          'startsAt': '2026-10-12T10:00:00Z',
          'endsAt': '2026-10-12T11:00:00Z',
          'totalPrice': 5000,
          'currency': 'KZT',
        },
      ]);

      final entries = await api.fetchSchedule('p1',
          from: DateTime.utc(2026, 10, 12), to: DateTime.utc(2026, 10, 13));

      expect(http.calls('GET', '/providers/p1/schedule').single.queryParameters,
          {'from': '2026-10-12T00:00:00.000Z', 'to': '2026-10-13T00:00:00.000Z'});
      expect(entries.single.currency, 'KZT');
      expect(entries.single.endsAt.toUtc(), DateTime.utc(2026, 10, 12, 11));
    });

    test('fetchBackup asks for the default window and parses bookings, customers and services', () async {
      http.reply('GET', '/providers/p1/backup', {
        'providerId': 'p1',
        'generatedAt': '2026-10-25T10:00:00Z',
        'from': '2026-09-25T10:00:00Z',
        'to': '2027-04-23T10:00:00Z',
        'bookings': [
          {
            'bookingId': 'b1',
            'startsAt': '2026-10-26T09:00:00Z',
            'endsAt': '2026-10-26T10:00:00Z',
            'status': 'CONFIRMED',
            'serviceTitle': 'Haircut',
            'staffName': 'Aigerim',
            'customerName': 'Ana',
            'customerPhone': '+77001112233',
            'customerEmail': null,
            'totalPrice': 9000,
            'currency': 'KZT',
          },
        ],
        'customers': [
          {
            'userId': 'u1',
            'name': 'Ana',
            'phone': '+77001112233',
            'email': 'ana@x.kz',
            'lastVisitAt': '2026-10-01T10:00:00Z',
            'totalBookings': 3,
            'totalSpent': 27000,
            'currency': 'KZT',
            'noShows': 1,
          },
          {'userId': 'u2', 'totalBookings': 0, 'totalSpent': 0, 'noShows': 0},
        ],
        'services': [
          {'title': 'Haircut', 'durationMinutes': 60, 'price': 9000, 'currency': 'KZT', 'active': true},
        ],
      });

      final backup = await api.fetchBackup('p1', providerName: 'Glow Salon');

      expect(http.calls('GET', '/providers/p1/backup').single.queryParameters, isEmpty);
      expect(backup.providerName, 'Glow Salon');
      expect(backup.bookings.single.customerPhone, '+77001112233');
      expect(backup.bookings.single.customerEmail, isNull);
      expect(backup.bookings.single.staffName, 'Aigerim');
      expect(backup.bookings.single.endsAt.toUtc(), DateTime.utc(2026, 10, 26, 10));
      expect(backup.customers.first.lastVisitAt!.toUtc(), DateTime.utc(2026, 10, 1, 10));
      expect(backup.customers.first.totalSpent, 27000);
      expect(backup.customers.last.name, isNull, reason: 'a customer the server has no details for');
      expect(backup.customers.last.lastVisitAt, isNull);
      expect(backup.services.single.durationMinutes, 60);
      expect(backup.services.single.active, isTrue);
    });

    test('fetchBackup tolerates a response with no lists', () async {
      http.reply('GET', '/providers/p1/backup', {
        'providerId': 'p1',
        'generatedAt': '2026-10-25T10:00:00Z',
        'from': '2026-09-25T10:00:00Z',
        'to': '2027-04-23T10:00:00Z',
      });

      final backup = await api.fetchBackup('p1', providerName: 'Glow');

      expect(backup.bookings, isEmpty);
      expect(backup.customers, isEmpty);
      expect(backup.services, isEmpty);
    });

    test('listPayouts parses settled and unsettled payouts', () async {
      http.reply('GET', '/providers/p1/payouts', [
        {
          'id': 'po1',
          'bookingId': 'b1',
          'paymentId': 'pay1',
          'providerId': 'p1',
          'amount': 4500,
          'currency': 'KZT',
          'status': 'PAID',
          'providerReference': 'bank-1',
          'createdAt': '2026-10-12T10:00:00Z',
          'settledAt': '2026-10-13T10:00:00Z',
        },
        {
          'id': 'po2',
          'bookingId': 'b2',
          'paymentId': 'pay2',
          'providerId': 'p1',
          'amount': 1000,
          'currency': 'KZT',
          'status': 'FAILED',
          'failureReason': 'bank down',
          'createdAt': '2026-10-12T10:00:00Z',
        },
      ]);

      final payouts = await api.listPayouts('p1');

      expect(payouts[0].settledAt, isNotNull);
      expect(payouts[0].providerReference, 'bank-1');
      expect(payouts[1].settledAt, isNull);
      expect(payouts[1].failureReason, 'bank down');
    });
  });

  group('dashboard and analytics', () {
    test('fetchDashboardMetrics parses the totals and top services', () async {
      http.reply('GET', '/providers/p1/dashboard', {
        'totalBookings': 10,
        'completedBookings': 6,
        'cancelledBookings': 2,
        'cancellationRate': 0.2,
        'totalCustomers': 7,
        'totalRevenue': 30000,
        'averageCheck': 5000,
        'currency': 'KZT',
        'topServices': [
          {'serviceId': 's1', 'title': 'Haircut', 'bookingCount': 4},
          {'serviceId': 's2', 'bookingCount': 1},
        ],
      });

      final metrics = await api.fetchDashboardMetrics('p1');

      expect(metrics.totalBookings, 10);
      expect(metrics.averageCheck, 5000);
      expect(metrics.topServices.map((s) => s.title), ['Haircut', null]);
      expect(metrics.topServices.first.bookingCount, 4);
    });

    test('analytics calls send only the range bounds that were given', () async {
      http.reply('GET', '/providers/p1/analytics/overview', {
        'totalBookings': 10,
        'completedBookings': 6,
        'upcomingBookings': 1,
        'cancelledBookings': 2,
        'noShowBookings': 1,
        'cancellationRate': 0.2,
        'noShowRate': 0.1,
        'totalRevenue': 30000,
        'returningCustomerRate': 0.5,
        'revenueRecovered': 8000,
      });

      final overview = await api.fetchAnalyticsOverview('p1');
      expect(http.calls('GET', '/providers/p1/analytics/overview').single.queryParameters, isEmpty);
      expect(overview.noShowBookings, 1);
      expect(overview.utilization, isNull);
      expect(overview.revenueRecovered, 8000);

      await api.fetchAnalyticsOverview('p1', from: DateTime.utc(2026, 10, 1));
      expect(http.calls('GET', '/providers/p1/analytics/overview').last.queryParameters,
          {'from': '2026-10-01T00:00:00.000Z'});

      await api.fetchAnalyticsOverview('p1', from: DateTime.utc(2026, 10, 1), to: DateTime.utc(2026, 10, 31));
      expect(http.calls('GET', '/providers/p1/analytics/overview').last.queryParameters,
          {'from': '2026-10-01T00:00:00.000Z', 'to': '2026-10-31T00:00:00.000Z'});
    });

    test('fetchAnalyticsRevenue parses the daily, per-service and per-staff breakdowns', () async {
      http.reply('GET', '/providers/p1/analytics/revenue', {
        'totalRevenue': 30000,
        'currency': 'KZT',
        'averageBookingValue': 5000,
        'revenueByDay': [
          {'date': '2026-10-11', 'amount': 10000},
        ],
        'revenueByService': [
          {'serviceId': 's1', 'title': 'Haircut', 'amount': 20000, 'bookingCount': 4},
        ],
        'revenueByStaff': [
          {'employeeId': 'w1', 'amount': 15000, 'bookingCount': 3},
          {'amount': 15000, 'bookingCount': 3},
        ],
        'revenueRecovered': 8000,
        'revenueRecoveredCurrency': 'KZT',
      });

      final revenue = await api.fetchAnalyticsRevenue('p1', from: DateTime.utc(2026, 10, 1));

      expect(revenue.revenueByDay.single.amount, 10000);
      expect(revenue.revenueByDay.single.date, DateTime(2026, 10, 11));
      expect(revenue.revenueByService.single.bookingCount, 4);
      expect(revenue.revenueByStaff.map((s) => s.employeeId), ['w1', null]);
      expect(revenue.revenueRecoveredCurrency, 'KZT');
    });

    test('fetchAnalyticsBookings parses the trend', () async {
      http.reply('GET', '/providers/p1/analytics/bookings', {
        'totalBookings': 10,
        'completedBookings': 6,
        'upcomingBookings': 1,
        'cancelledBookings': 2,
        'noShowBookings': 1,
        'cancellationRate': 0.2,
        'noShowRate': 0.1,
        'repeatBookingRate': 0.4,
        'trend': [
          {'date': '2026-10-11', 'total': 3, 'completed': 2, 'cancelled': 1, 'noShow': 0},
        ],
      });

      final bookings = await api.fetchAnalyticsBookings('p1');

      expect(bookings.repeatBookingRate, 0.4);
      expect(bookings.trend.single.cancelled, 1);
    });

    test('fetchAnalyticsCustomers parses the retention counts and favourite services', () async {
      http.reply('GET', '/providers/p1/analytics/customers', {
        'totalCustomers': 20,
        'activeCustomers': 10,
        'returningCustomers': 8,
        'newCustomers': 5,
        'dueForRebooking': 3,
        'atRiskCustomers': 2,
        'inactiveCustomers': 1,
        'averageVisitIntervalDays': 28.5,
        'averageCustomerValue': 12000,
        'currency': 'KZT',
        'favouriteServices': [
          {'serviceId': 's1', 'title': 'Haircut', 'customerCount': 6},
        ],
      });

      final customers = await api.fetchAnalyticsCustomers('p1');

      expect(customers.dueForRebooking, 3);
      expect(customers.averageVisitIntervalDays, 28.5);
      expect(customers.favouriteServices.single.customerCount, 6);
    });

    test('fetchAnalyticsSmartFill parses the recovery numbers', () async {
      http.reply('GET', '/providers/p1/analytics/smart-fill', {
        'slotsFreed': 10,
        'campaignsCreated': 8,
        'candidatesNotified': 30,
        'offersViewed': 12,
        'slotsRecovered': 4,
        'recoveryRate': 0.4,
        'recoveredRevenue': 20000,
        'currency': 'KZT',
      });

      final smartFill = await api.fetchAnalyticsSmartFill('p1');

      expect(smartFill.slotsRecovered, 4);
      expect(smartFill.recoveryRate, 0.4);
      expect(smartFill.currency, 'KZT');
    });

    test('fetchAnalyticsActions parses every action type and rejects an unknown one', () async {
      http.reply('GET', '/providers/p1/analytics/actions', {
        'actions': [
          {'type': 'SMART_FILL_OPPORTUNITY', 'count': 1},
          {'type': 'REBOOK_OPPORTUNITY', 'count': 2},
          {'type': 'RETENTION_RISK', 'count': 3},
          {'type': 'LOW_UTILIZATION', 'count': 4},
        ],
      });

      final center = await api.fetchAnalyticsActions('p1');

      expect(center.actions.map((a) => a.type), ActionItemType.values);
      expect(center.actions.map((a) => a.count), [1, 2, 3, 4]);

      http.reply('GET', '/providers/p1/analytics/actions', {
        'actions': [
          {'type': 'SOMETHING_NEW', 'count': 1},
        ],
      });
      await expectLater(api.fetchAnalyticsActions('p1'), throwsA(isA<ArgumentError>()));
    });

    test('fetchActiveSmartFillCampaigns parses recovered and open campaigns', () async {
      http.reply('GET', '/providers/p1/analytics/smart-fill/active', [
        {
          'campaignId': 'c1',
          'status': 'NOTIFYING',
          'slotStartsAt': '2026-10-12T10:00:00Z',
          'candidatesNotified': 3,
        },
        {
          'campaignId': 'c2',
          'status': 'BOOKED',
          'slotStartsAt': '2026-10-12T12:00:00Z',
          'candidatesNotified': 5,
          'recoveredBookingId': 'b9',
        },
      ]);

      final campaigns = await api.fetchActiveSmartFillCampaigns('p1');

      expect(campaigns.map((c) => c.recoveredBookingId), [null, 'b9']);
      expect(campaigns.first.candidatesNotified, 3);
    });

    test('fetchCustomerList filters by retention status using its wire name', () async {
      http.reply('GET', '/providers/p1/analytics/customers/list', [
        {
          'userId': 'u1',
          'displayName': 'Aigerim',
          'email': 'a@example.com',
          'retentionStatus': 'DUE_FOR_REBOOKING',
          'lastVisitAt': '2026-09-01T10:00:00Z',
          'nextExpectedVisitAt': '2026-10-01T10:00:00Z',
          'totalSpent': 25000,
          'currency': 'KZT',
          'favouriteServiceTitle': 'Haircut',
          'noShows': 2,
        },
        {'userId': 'u2', 'retentionStatus': 'NEW', 'totalSpent': 0},
      ]);

      final all = await api.fetchCustomerList('p1');
      expect(http.calls('GET', '/providers/p1/analytics/customers/list').single.queryParameters, isEmpty);
      expect(all[0].retentionStatus, CustomerRetentionStatus.dueForRebooking);
      expect(all[0].lastVisitAt, isNotNull);
      expect(all[1].lastVisitAt, isNull);
      expect(all[0].noShows, 2);
      expect(all[1].noShows, 0);
      expect(all[1].displayName, isNull);

      await api.fetchCustomerList('p1', retentionStatus: CustomerRetentionStatus.atRisk);
      expect(http.calls('GET', '/providers/p1/analytics/customers/list').last.queryParameters,
          {'retentionStatus': 'AT_RISK'});
    });

    test('every retention status round-trips through its wire name', () {
      for (final status in CustomerRetentionStatus.values) {
        expect(CustomerRetentionStatus.fromWire(status.toWire()), status);
      }
      expect(CustomerRetentionStatus.newCustomer.toWire(), 'NEW');
      expect(() => CustomerRetentionStatus.fromWire('???'), throwsArgumentError);
    });
  });
}

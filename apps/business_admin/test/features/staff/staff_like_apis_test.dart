import 'package:business_admin/features/auto/data/auto_admin_api.dart';
import 'package:business_admin/features/beauty/data/beauty_admin_api.dart';
import 'package:business_admin/features/billing/data/billing_exception.dart';
import 'package:business_admin/features/cleaning/data/cleaning_admin_api.dart';
import 'package:business_admin/features/staff/data/staff_admin_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

/// Masters (beauty), cleaners, mechanics and staff share one API shape; this
/// runs the same checks against all four, so a rename or a copy-paste slip in
/// one of them shows up here.
class _Case {
  _Case({
    required this.name,
    required this.list,
    required this.create,
    required this.services,
    required this.link,
    required this.unlink,
    required this.photo,
    required this.deactivate,
    required this.reactivate,
    required this.listPath,
    required this.createPath,
    required this.servicesPath,
    required this.linkPath,
    required this.photoPath,
    required this.deactivatePath,
    required this.reactivatePath,
  });

  final String name;
  final Future<List<Object?>> Function(FakeHttp http, {bool includeInactive}) list;
  final Future<Object?> Function(FakeHttp http) create;
  final Future<List<Object?>> Function(FakeHttp http) services;
  final Future<void> Function(FakeHttp http) link;
  final Future<void> Function(FakeHttp http) unlink;
  final Future<Object?> Function(FakeHttp http, String? url) photo;
  final Future<void> Function(FakeHttp http) deactivate;
  final Future<Object?> Function(FakeHttp http) reactivate;
  final String listPath, createPath, servicesPath, linkPath, photoPath, deactivatePath, reactivatePath;
}

final _cases = <_Case>[
  _Case(
    name: 'beauty masters',
    list: (h, {bool includeInactive = false}) =>
        BeautyAdminApi(h.client()).listMasters('p1', includeInactive: includeInactive),
    create: (h) => BeautyAdminApi(h.client()).createMasterFromUser(providerId: 'p1', userId: 'u1'),
    services: (h) => BeautyAdminApi(h.client()).listMasterServices('m1'),
    link: (h) => BeautyAdminApi(h.client()).linkService(masterId: 'm1', serviceId: 's1'),
    unlink: (h) => BeautyAdminApi(h.client()).unlinkService(masterId: 'm1', serviceId: 's1'),
    photo: (h, url) => BeautyAdminApi(h.client()).updateMasterPhoto('m1', url),
    deactivate: (h) => BeautyAdminApi(h.client()).deactivateMaster('m1'),
    reactivate: (h) => BeautyAdminApi(h.client()).reactivateMaster('m1'),
    listPath: '/beauty/providers/p1/masters',
    createPath: '/beauty/providers/p1/masters/from-user',
    servicesPath: '/beauty/masters/m1/services',
    linkPath: '/beauty/masters/m1/services/s1',
    photoPath: '/beauty/masters/m1/photo',
    deactivatePath: '/beauty/masters/m1',
    reactivatePath: '/beauty/masters/m1/reactivate',
  ),
  _Case(
    name: 'cleaners',
    list: (h, {bool includeInactive = false}) =>
        CleaningAdminApi(h.client()).listCleaners('p1', includeInactive: includeInactive),
    create: (h) => CleaningAdminApi(h.client()).createCleanerFromUser(providerId: 'p1', userId: 'u1'),
    services: (h) => CleaningAdminApi(h.client()).listCleanerServices('m1'),
    link: (h) => CleaningAdminApi(h.client()).linkService(cleanerId: 'm1', serviceId: 's1'),
    unlink: (h) => CleaningAdminApi(h.client()).unlinkService(cleanerId: 'm1', serviceId: 's1'),
    photo: (h, url) => CleaningAdminApi(h.client()).updateCleanerPhoto('m1', url),
    deactivate: (h) => CleaningAdminApi(h.client()).deactivateCleaner('m1'),
    reactivate: (h) => CleaningAdminApi(h.client()).reactivateCleaner('m1'),
    listPath: '/cleaning/providers/p1/cleaners',
    createPath: '/cleaning/providers/p1/cleaners/from-user',
    servicesPath: '/cleaning/cleaners/m1/services',
    linkPath: '/cleaning/cleaners/m1/services/s1',
    photoPath: '/cleaning/cleaners/m1/photo',
    deactivatePath: '/cleaning/cleaners/m1',
    reactivatePath: '/cleaning/cleaners/m1/reactivate',
  ),
  _Case(
    name: 'auto mechanics',
    list: (h, {bool includeInactive = false}) =>
        AutoAdminApi(h.client()).listMechanics('p1', includeInactive: includeInactive),
    create: (h) => AutoAdminApi(h.client()).createMechanicFromUser(providerId: 'p1', userId: 'u1'),
    services: (h) => AutoAdminApi(h.client()).listMechanicServices('m1'),
    link: (h) => AutoAdminApi(h.client()).linkService(mechanicId: 'm1', serviceId: 's1'),
    unlink: (h) => AutoAdminApi(h.client()).unlinkService(mechanicId: 'm1', serviceId: 's1'),
    photo: (h, url) => AutoAdminApi(h.client()).updateMechanicPhoto('m1', url),
    deactivate: (h) => AutoAdminApi(h.client()).deactivateMechanic('m1'),
    reactivate: (h) => AutoAdminApi(h.client()).reactivateMechanic('m1'),
    listPath: '/auto/providers/p1/mechanics',
    createPath: '/auto/providers/p1/mechanics/from-user',
    servicesPath: '/auto/mechanics/m1/services',
    linkPath: '/auto/mechanics/m1/services/s1',
    photoPath: '/auto/mechanics/m1/photo',
    deactivatePath: '/auto/mechanics/m1',
    reactivatePath: '/auto/mechanics/m1/reactivate',
  ),
  _Case(
    name: 'generic staff',
    list: (h, {bool includeInactive = false}) =>
        StaffAdminApi(h.client()).listStaff('p1', includeInactive: includeInactive),
    create: (h) => StaffAdminApi(h.client()).createStaffFromUser(providerId: 'p1', userId: 'u1'),
    services: (h) => StaffAdminApi(h.client()).listStaffServices('m1'),
    link: (h) => StaffAdminApi(h.client()).linkService(staffId: 'm1', serviceId: 's1'),
    unlink: (h) => StaffAdminApi(h.client()).unlinkService(staffId: 'm1', serviceId: 's1'),
    photo: (h, url) => StaffAdminApi(h.client()).updateStaffPhoto('m1', url),
    deactivate: (h) => StaffAdminApi(h.client()).deactivateStaff('m1'),
    reactivate: (h) => StaffAdminApi(h.client()).reactivateStaff('m1'),
    listPath: '/providers/p1/staff',
    createPath: '/providers/p1/staff/from-user',
    servicesPath: '/staff/m1/services',
    linkPath: '/staff/m1/services/s1',
    photoPath: '/staff/m1/photo',
    deactivatePath: '/staff/m1',
    reactivatePath: '/staff/m1/reactivate',
  ),
];

const _person = {
  'id': 'm1',
  'providerId': 'p1',
  'displayName': 'Aigerim',
  'bio': 'Ten years of experience',
  'photoUrl': 'https://img/a.png',
  'active': true,
};

const _serviceSummary = {
  'serviceId': 's1',
  'title': 'Haircut',
  'durationMinutes': 60,
  'price': 5000,
  'currency': 'KZT',
};

void main() {
  for (final c in _cases) {
    group(c.name, () {
      late FakeHttp http;
      setUp(() => http = FakeHttp());

      test('list parses people and asks for inactive ones only when told to', () async {
        http.reply('GET', c.listPath, [
          _person,
          {'id': 'm2', 'providerId': 'p1', 'displayName': 'Bare', 'active': false},
        ]);

        final people = await c.list(http);
        expect(people, hasLength(2));
        final first = people.first as dynamic;
        expect([first.id, first.providerId, first.displayName, first.bio, first.photoUrl, first.active],
            ['m1', 'p1', 'Aigerim', 'Ten years of experience', 'https://img/a.png', true]);
        final bare = people.last as dynamic;
        expect([bare.bio, bare.photoUrl, bare.active], [null, null, false]);
        expect(http.calls('GET', c.listPath).single.queryParameters, {'includeInactive': false});

        await c.list(http, includeInactive: true);
        expect(http.calls('GET', c.listPath).last.queryParameters, {'includeInactive': true});
      });

      test('create posts the user id and parses the new person', () async {
        http.reply('POST', c.createPath, _person);

        final created = await c.create(http);

        expect(http.bodyOf('POST', c.createPath), {'userId': 'u1'});
        expect((created as dynamic).displayName, 'Aigerim');
      });

      test('create maps 402 to "staff limit reached" and rethrows other errors', () async {
        http.fail('POST', c.createPath, 402);
        try {
          await c.create(http);
          fail('expected a BillingException');
        } on BillingException catch (e) {
          expect(e.key, SubscriptionErrorKey.staffLimitReached);
        }

        http.fail('POST', c.createPath, 500);
        await expectLater(c.create(http), throwsA(isA<DioException>()));
      });

      test('the services list parses title, duration and price', () async {
        http.reply('GET', c.servicesPath, [_serviceSummary]);

        final services = await c.services(http);

        expect(services, hasLength(1));
        final service = services.single as dynamic;
        expect([service.serviceId, service.title, service.durationMinutes, service.price, service.currency],
            ['s1', 'Haircut', 60, 5000.0, 'KZT']);
      });

      test('link posts and unlink deletes the same service path', () async {
        http
          ..reply('POST', c.linkPath, <String, Object?>{})
          ..reply('DELETE', c.linkPath, <String, Object?>{});

        await c.link(http);
        await c.unlink(http);

        expect(http.calls('POST', c.linkPath), hasLength(1));
        expect(http.calls('DELETE', c.linkPath), hasLength(1));
      });

      test('the photo is put as a url, and null removes it', () async {
        http.reply('PUT', c.photoPath, _person);

        await c.photo(http, 'https://img/new.png');
        expect(http.bodyOf('PUT', c.photoPath), {'photoUrl': 'https://img/new.png'});

        http.requests.clear();
        await c.photo(http, null);
        expect(http.bodyOf('PUT', c.photoPath), {'photoUrl': null});
      });

      test('deactivate deletes and reactivate posts', () async {
        http
          ..reply('DELETE', c.deactivatePath, <String, Object?>{})
          ..reply('POST', c.reactivatePath, _person);

        await c.deactivate(http);
        final back = await c.reactivate(http);

        expect(http.calls('DELETE', c.deactivatePath), hasLength(1));
        expect(http.calls('POST', c.reactivatePath), hasLength(1));
        expect((back as dynamic).active, isTrue);
      });
    });
  }

  group('beauty portfolio', () {
    late FakeHttp http;
    late BeautyAdminApi api;

    setUp(() {
      http = FakeHttp();
      api = BeautyAdminApi(http.client());
    });

    test('listPortfolio parses items with and without a caption', () async {
      http.reply('GET', '/beauty/masters/m1/portfolio', [
        {'id': 'i1', 'masterId': 'm1', 'imageUrl': 'https://img/1.png', 'caption': 'Balayage'},
        {'id': 'i2', 'masterId': 'm1', 'imageUrl': 'https://img/2.png'},
      ]);

      final items = await api.listPortfolio('m1');

      expect(items.map((i) => i.caption), ['Balayage', null]);
      expect(items.first.imageUrl, 'https://img/1.png');
      expect(items.first.masterId, 'm1');
    });

    test('addPortfolioItem posts the image and caption', () async {
      http.reply('POST', '/beauty/masters/m1/portfolio',
          {'id': 'i3', 'masterId': 'm1', 'imageUrl': 'https://img/3.png', 'caption': 'New'});

      final item = await api.addPortfolioItem(masterId: 'm1', imageUrl: 'https://img/3.png', caption: 'New');

      expect(http.bodyOf('POST', '/beauty/masters/m1/portfolio'),
          {'imageUrl': 'https://img/3.png', 'caption': 'New'});
      expect(item.id, 'i3');
    });
  });
}

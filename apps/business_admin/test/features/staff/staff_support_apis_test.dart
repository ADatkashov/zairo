import 'package:business_admin/features/staff/data/invitations_api.dart';
import 'package:business_admin/features/staff/data/staff_cabinet_link_api.dart';
import 'package:business_admin/features/staff/data/user_lookup_api.dart';
import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

void main() {
  late FakeHttp http;

  setUp(() => http = FakeHttp());

  group('InvitationsApi', () {
    test('invite posts the phone and parses the invitation', () async {
      http.reply('POST', '/providers/p1/staff-invitations',
          {'id': 'i1', 'providerId': 'p1', 'phone': '+77001234567', 'kind': 'MASTER', 'status': 'PENDING'});

      final invitation = await InvitationsApi(http.client()).invite(providerId: 'p1', phone: '+77001234567');

      expect(http.bodyOf('POST', '/providers/p1/staff-invitations'), {'phone': '+77001234567'});
      expect([invitation.id, invitation.providerId, invitation.phone, invitation.kind, invitation.status],
          ['i1', 'p1', '+77001234567', 'MASTER', 'PENDING']);
    });

    test('listPending returns the open invitations and cancel deletes one', () async {
      http.reply('GET', '/providers/p1/staff-invitations', [
        {'id': 'i1', 'providerId': 'p1', 'phone': '+7700', 'kind': 'MASTER', 'status': 'PENDING'},
        {'id': 'i2', 'providerId': 'p1', 'phone': '+7701', 'kind': 'STAFF', 'status': 'PENDING'},
      ]);
      http.reply('DELETE', '/staff-invitations/i1', <String, Object?>{});
      final api = InvitationsApi(http.client());

      expect((await api.listPending('p1')).map((i) => i.id), ['i1', 'i2']);
      await api.cancel('i1');

      expect(http.calls('DELETE', '/staff-invitations/i1'), hasLength(1));
    });

    test('the providers read through the shared Dio client', () async {
      http.reply('GET', '/providers/p1/staff-invitations', [
        {'id': 'i1', 'providerId': 'p1', 'phone': '+7700', 'kind': 'MASTER', 'status': 'PENDING'},
      ]);
      final container = ProviderContainer(overrides: [dioClientProvider.overrideWithValue(http.client())]);
      addTearDown(container.dispose);

      expect(container.read(invitationsApiProvider), isA<InvitationsApi>());
      expect(container.read(userLookupApiProvider), isA<UserLookupApi>());
      final pending = await container.read(pendingInvitationsProvider('p1').future);
      expect(pending.single.id, 'i1');
    });
  });

  group('UserLookupApi', () {
    test('lookupByPhone finds a user, with or without an avatar', () async {
      http.reply('GET', '/users/lookup', {'id': 'u1', 'displayName': 'Aigerim', 'avatarUrl': 'https://img/a.png'});
      final api = UserLookupApi(http.client());

      final user = await api.lookupByPhone('+7700');
      expect(http.calls('GET', '/users/lookup').single.queryParameters, {'phone': '+7700'});
      expect([user!.id, user.displayName, user.avatarUrl], ['u1', 'Aigerim', 'https://img/a.png']);

      http.reply('GET', '/users/lookup', {'id': 'u2', 'displayName': 'Bare'});
      expect((await api.lookupByPhone('+7701'))!.avatarUrl, isNull);
    });

    test('an unknown phone is null (404), other errors pass through', () async {
      final api = UserLookupApi(http.client());

      http.fail('GET', '/users/lookup', 404);
      expect(await api.lookupByPhone('+7700'), isNull);

      http.fail('GET', '/users/lookup', 500);
      await expectLater(api.lookupByPhone('+7700'), throwsA(isA<DioException>()));
    });
  });

  group('StaffCabinetLinkApi', () {
    test('pendingAppointments is null for someone who is not on any team', () async {
      http.reply('GET', '/me/staff-memberships', <Object?>[]);

      expect(await StaffCabinetLinkApi(http.client()).pendingAppointments(), isNull);
    });

    test('pendingAppointments adds up the pending count over every team', () async {
      http.reply('GET', '/me/staff-memberships', [
        {'pendingCount': 2},
        {'pendingCount': 3},
        {'pendingCount': 0},
      ]);

      expect(await StaffCabinetLinkApi(http.client()).pendingAppointments(), 5);
    });
  });
}

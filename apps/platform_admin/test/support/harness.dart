import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/app.dart';
import 'package:platform_admin/app/router.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/core/network/platform_http.dart';
import 'package:platform_admin/l10n/app_localizations.dart';

import 'fake_backend.dart';

/// Secure storage that lives in memory.
class MemoryStorage extends SecureStorageService {
  MemoryStorage([Map<String, String>? initial]) : values = {...?initial}, super(const FlutterSecureStorage());

  final Map<String, String> values;

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// A syntactically valid JWT that expires [validFor] from now.
String fakeJwt({Duration validFor = const Duration(minutes: 30)}) {
  String part(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp, 'sub': 'admin'})}.signature';
}

Map<String, Object?> adminJson({
  String role = 'PLATFORM_ADMIN',
  String email = 'boss@zairo.kz',
  String name = 'Aida Boss',
  String id = 'a1',
}) => {'id': id, 'email': email, 'displayName': name, 'role': role, 'active': true, 'avatarUrl': null};

Map<String, Object?> businessJson(String id, String name, String status, {String vertical = 'beauty'}) => {
  'id': id,
  'ownerUserId': 'owner-$id',
  'name': name,
  'vertical': vertical,
  'status': status,
  'createdAt': '2026-09-01T10:00:00Z',
  'latitude': 43.238,
  'longitude': 76.945,
  'businessTypeId': null,
  'coverPhotoUrl': null,
};

Map<String, Object?> payoutJson(String id, String status, {String providerId = 'p2', num amount = 25000}) => {
  'id': id,
  'bookingId': 'b-$id',
  'paymentId': 'pay-$id',
  'providerId': providerId,
  'amount': amount,
  'currency': 'KZT',
  'status': status,
  'providerReference': status == 'PAID' ? 'kaspi-1' : null,
  'failureReason': null,
  'createdAt': '2026-09-20T09:00:00Z',
  'settledAt': status == 'PAID' ? '2026-09-21T09:00:00Z' : null,
};

Map<String, Object?> catalogJson(
  String id,
  String en, {
  String? code,
  String status = 'ACTIVE',
  String? icon,
  int sort = 10,
  String? subsphereId,
}) => {
  'id': id,
  'code': code,
  'nameEn': en,
  'nameRu': '$en RU',
  'nameKk': '$en KK',
  'icon': icon,
  'sortOrder': sort,
  'status': status,
  'subsphereId': subsphereId,
};

Map<String, Object?> cityJson(String code, String name, {bool active = true}) => {
  'code': code,
  'name': name,
  'name_kk': '$name KK',
  'country_code': 'KZ',
  'timezone': 'Asia/Almaty',
  'currency': 'KZT',
  'latitude': 43.2,
  'longitude': 76.9,
  'default_search_radius_km': 50,
  'active': active,
};

/// A backend with believable data for every area; tests change what they need.
FakeBackend defaultBackend({String role = 'PLATFORM_ADMIN'}) {
  final backend = FakeBackend();
  final admin = adminJson(role: role);
  backend.reply('POST', loginPath, {'accessToken': fakeJwt(), 'admin': admin});
  backend.reply('GET', '/platform/auth/me', admin);
  backend.reply('GET', '/platform/dashboard', {
    'users': {'total': 1200},
    'businesses': {'total': 12, 'active': 9, 'pendingModeration': 1, 'blocked': 2},
    'subscriptions': {'free': 7, 'pro': 5, 'active': 5, 'pastDue': 1, 'cancelled': 2},
    'bookings': {'today': 14, 'thisWeek': 90, 'thisMonth': 350, 'completed': 800, 'cancelled': 40},
    'payments': {'succeeded': 700, 'failed': 12, 'pending': 5, 'refunded': 20, 'refundFailed': 1},
    'revenue': {'mrr': 150000, 'currency': 'KZT', 'platformCommission': 42000, 'platformCommissionCurrency': 'KZT'},
  });
  final businesses = [businessJson('p1', 'Glow Salon', 'PENDING'), businessJson('p2', 'Zen Spa', 'ACTIVE')];
  backend.on('GET', '/platform/businesses', (_) => FakeReply(businesses));
  backend.on('PATCH', '/platform/businesses/p1/status', (o) {
    businesses[0] = businessJson('p1', 'Glow Salon', (o.data as Map)['status'] as String);
    return const FakeReply({});
  });
  backend.on('PATCH', '/platform/businesses/p2/status', (o) {
    businesses[1] = businessJson('p2', 'Zen Spa', (o.data as Map)['status'] as String);
    return const FakeReply({});
  });
  backend.on('GET', '/platform/payouts', (o) {
    final all = [payoutJson('po1', 'PAYABLE'), payoutJson('po2', 'PAID', amount: 10000)];
    final status = o.queryParameters['status'];
    return FakeReply(status == null ? all : all.where((p) => p['status'] == status).toList());
  });
  backend.reply('GET', '/platform/payments/failed-refunds', [
    {
      'id': 'pay-9',
      'bookingId': 'b-9',
      'amount': 5000,
      'currency': 'KZT',
      'status': 'REFUND_FAILED',
      'provider': 'FREEDOM_PAY',
      'providerReference': 'fp-9',
      'refundFailureReason': 'Provider timeout',
      'refundAttempts': 3,
      'createdAt': '2026-09-25T09:00:00Z',
    },
  ]);
  backend.on(
    'GET',
    '/platform/payments/refund-requests',
    (o) => FakeReply(
      o.queryParameters['status'] == 'RETRY'
          ? [
              {
                'id': 'rr1',
                'paymentId': 'pay-7',
                'bookingId': 'b-7',
                'amount': 7000,
                'currency': 'KZT',
                'status': 'RETRY',
                'attempts': 2,
                'nextAttemptAt': '2026-10-06T09:00:00Z',
                'lastError': 'pg_status=error',
                'createdAt': '2026-10-05T09:00:00Z',
              },
            ]
          : [],
    ),
  );
  backend.reply('POST', '/platform/payments/pay-9/reconcile', {
    'outcome': 'DISCREPANCY',
    'localStatus': 'REFUND_FAILED',
    'providerStatus': 'SUCCEEDED',
    'providerReference': 'fp-9',
  });
  backend.reply('GET', '/platform/categories', [catalogJson('c1', 'Beauty', code: 'beauty', icon: '💅')]);
  backend.reply('GET', '/platform/categories/c1/business-types', [catalogJson('s1', 'Hair Salon', code: 'hair_salon')]);
  backend.reply('GET', '/platform/business-types/s1/subspheres', [catalogJson('ss1', 'Barbering', code: 'barbering')]);
  backend.reply('GET', '/platform/business-types/s1/services', [catalogJson('sv1', 'Haircut', subsphereId: 'ss1')]);
  backend.reply('GET', '/cities', [cityJson('almaty', 'Almaty'), cityJson('shymkent', 'Shymkent', active: false)]);
  backend.reply('GET', '/countries', [
    {'code': 'KZ', 'name': 'Kazakhstan', 'timezone': 'Asia/Almaty', 'currency': 'KZT'},
  ]);
  backend.reply('GET', '/platform/admins', [
    admin,
    adminJson(role: 'PLATFORM_MODERATOR', email: 'mod@zairo.kz', name: 'Mara Mod', id: 'a2'),
  ]);
  backend.reply('GET', '/platform/audit-log', {
    'content': [
      {
        'id': 'e1',
        'actorEmail': 'boss@zairo.kz',
        'action': 'PROVIDER_STATUS_CHANGED',
        'targetType': 'PROVIDER',
        'targetId': 'p2',
        'previousValue': 'PENDING',
        'newValue': 'ACTIVE',
        'reason': null,
        'createdAt': '2026-10-05T10:30:00Z',
      },
      {
        'id': 'e2',
        'actorEmail': 'boss@zairo.kz',
        'action': 'CATEGORY_CREATED',
        'targetType': 'CATEGORY',
        'targetId': 'c1',
        'previousValue': null,
        'newValue': null,
        'reason': null,
        'createdAt': '2026-10-04T10:30:00Z',
      },
    ],
  });
  return backend;
}

/// Pumps the whole console against [backend]. [signedIn] starts with a valid
/// stored token, so the app restores the session; otherwise it starts at the
/// login screen.
Future<MemoryStorage> pumpConsole(
  WidgetTester tester, {
  required FakeBackend backend,
  bool signedIn = true,
  Size size = const Size(1400, 900),
  Locale locale = const Locale('en'),
  String location = ConsoleRoutes.dashboard,
  MemoryStorage? storage,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store =
      storage ?? MemoryStorage({'locale_code': locale.languageCode, if (signedIn) 'platform_access_token': fakeJwt()});
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per call, so a test can open several areas in turn.
      key: UniqueKey(),
      overrides: [
        secureStorageServiceProvider.overrideWithValue(store),
        httpClientAdapterOverrideProvider.overrideWithValue(backend),
        networkConfigProvider.overrideWithValue(const NetworkConfig(baseUrl: 'http://test/api/v1')),
        initialLocationProvider.overrideWithValue(location),
        ...extraOverrides,
      ],
      child: const PlatformAdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

Finder byTextContaining(String text) => find.textContaining(text);

ThemeData get testTheme => factoryLightTheme();

/// Secure storage that refuses everything, like a desktop without a keychain.
class BrokenStorage extends MemoryStorage {
  @override
  Future<void> write(String key, String value) async => throw StateError('keychain unavailable');

  @override
  Future<String?> read(String key) async => throw StateError('keychain unavailable');

  @override
  Future<void> delete(String key) async => throw StateError('keychain unavailable');
}

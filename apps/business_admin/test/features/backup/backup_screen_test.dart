import 'dart:async';
import 'dart:typed_data';

import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/backup/data/backup_sharer.dart';
import 'package:business_admin/features/backup/data/business_backup.dart';
import 'package:business_admin/features/backup/presentation/backup_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/features/settings/presentation/screens/settings_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends SalonAdminApi {
  _FakeApi(this._providers) : super(DioClient(Dio()));

  final List<AdminProvider> _providers;

  /// Businesses whose copy cannot be fetched.
  final failing = <String>{};
  final fetched = <String>[];

  /// When set, fetching waits for it — to look at the screen while it is working.
  Completer<void>? gate;

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => _providers;

  @override
  Future<BusinessBackup> fetchBackup(String providerId, {required String providerName}) async {
    await gate?.future;
    if (failing.contains(providerId)) throw StateError('offline');
    fetched.add(providerId);
    return BusinessBackup(
      providerId: providerId,
      providerName: providerName,
      generatedAt: DateTime.utc(2026, 10, 25),
      from: DateTime.utc(2026, 9, 25),
      to: DateTime.utc(2027, 4, 23),
      bookings: [
        BackupBooking(
          startsAt: DateTime(2026, 10, 26, 9),
          endsAt: DateTime(2026, 10, 26, 10),
          status: 'CONFIRMED',
          serviceTitle: 'Haircut',
          customerName: 'Ana at $providerName',
          customerPhone: '+77001112233',
          totalPrice: 9000,
          currency: 'KZT',
        ),
      ],
      customers: const [BackupCustomer(name: 'Ana', totalBookings: 1, totalSpent: 9000, noShows: 0)],
      services: const [BackupService(title: 'Haircut', durationMinutes: 60, price: 9000, active: true)],
    );
  }
}

class _Owner extends AuthController {
  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'owner-1', email: 'o@x.kz', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
}

const _glow = AdminProvider(id: 'p1', ownerUserId: 'owner-1', name: 'Glow', vertical: 'beauty', status: 'ACTIVE');
const _garage = AdminProvider(id: 'p2', ownerUserId: 'owner-1', name: 'Garage', vertical: 'auto', status: 'ACTIVE');

class _Shared {
  Uint8List? bytes;
  String? name;
  int calls = 0;
}

Future<void> _pump(
  WidgetTester tester,
  _FakeApi api,
  _Shared shared, {
  bool dismiss = false,
  Object? shareError,
  Size size = const Size(400, 800),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salonAdminApiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_Owner.new),
        backupSharerProvider.overrideWithValue((bytes, name) async {
          shared
            ..calls += 1
            ..bytes = bytes
            ..name = name;
          if (shareError != null) throw shareError;
          return !dismiss;
        }),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BackupScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says what the copy holds and that it is personal data, with one button', (tester) async {
    await _pump(tester, _FakeApi([_glow]), _Shared());

    expect(find.text('Backup copy'), findsOneWidget);
    expect(find.textContaining('keep working from it'), findsOneWidget);
    expect(find.textContaining('Schedule: the last 30 days'), findsOneWidget);
    expect(find.textContaining('Customers: contacts'), findsOneWidget);
    expect(find.textContaining('Services with prices'), findsOneWidget);
    expect(find.textContaining('personal data'), findsOneWidget);
    expect(find.text('Save a copy'), findsOneWidget);
  });

  testWidgets('one tap builds the workbook, hands it over under a dated name, and reports the counts', (tester) async {
    final shared = _Shared();
    await _pump(tester, _FakeApi([_glow]), shared);

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(shared.calls, 1);
    expect(shared.name, matches(RegExp(r'^zairo-backup-\d{4}-\d{2}-\d{2}\.xlsx$')));
    final sheets = Excel.decodeBytes(shared.bytes!).tables;
    expect(sheets.keys, unorderedEquals(['Schedule', 'Customers', 'Services']));
    expect(sheets['Schedule']!.rows[1][6]!.value.toString(), 'Ana at Glow');
    expect(find.text('Copy ready. Bookings: 1, customers: 1.'), findsOneWidget);
  });

  testWidgets('every business of the owner goes into the one file', (tester) async {
    final shared = _Shared();
    final api = _FakeApi([_glow, _garage]);
    await _pump(tester, api, shared);

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(api.fetched, unorderedEquals(['p1', 'p2']));
    final rows = Excel.decodeBytes(shared.bytes!).tables['Schedule']!.rows;
    expect(rows.skip(1).map((r) => r[0]!.value.toString()), ['Glow', 'Garage']);
    expect(find.text('Copy ready. Bookings: 2, customers: 2.'), findsOneWidget);
  });

  testWidgets('closing the share menu without choosing is not reported as saved', (tester) async {
    final shared = _Shared();
    await _pump(tester, _FakeApi([_glow]), shared, dismiss: true);

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(shared.calls, 1);
    expect(find.textContaining('Copy ready'), findsNothing);
    expect(find.byType(FactoryButton), findsOneWidget, reason: 'the button is back, to try again');
  });

  testWidgets('when the data cannot be loaded nothing is shared, and it says so', (tester) async {
    final shared = _Shared();
    final api = _FakeApi([_glow])..failing.add('p1');
    await _pump(tester, api, shared);

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(shared.calls, 0);
    expect(find.text('Couldn’t prepare the copy. Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('one business failing fails the whole copy, rather than quietly leaving a business out', (tester) async {
    final shared = _Shared();
    final api = _FakeApi([_glow, _garage])..failing.add('p2');
    await _pump(tester, api, shared);

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(shared.calls, 0);
    expect(find.textContaining('Couldn’t prepare the copy'), findsOneWidget);
  });

  testWidgets('a failing share menu is reported, and a retry can succeed', (tester) async {
    final shared = _Shared();
    await _pump(tester, _FakeApi([_glow]), shared, shareError: StateError('no share on this device'));

    await tester.tap(find.text('Save a copy'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t open the share menu on this device.'), findsOneWidget);
    expect(find.textContaining('Copy ready'), findsNothing);
  });

  testWidgets('the button shows progress and cannot be pressed twice while working', (tester) async {
    final shared = _Shared();
    final api = _FakeApi([_glow])..gate = Completer<void>();
    await _pump(tester, api, shared);

    await tester.tap(find.text('Save a copy'));
    await tester.pump();

    expect(tester.widget<FactoryButton>(find.byType(FactoryButton)).isLoading, isTrue);
    expect(tester.widget<FactoryButton>(find.byType(FactoryButton)).onPressed, isNull);

    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(shared.calls, 1);
    expect(tester.widget<FactoryButton>(find.byType(FactoryButton)).isLoading, isFalse);
  });

  testWidgets('is readable in Russian and Kazakh, on a 320 px phone at double font', (tester) async {
    for (final locale in const [Locale('ru'), Locale('kk')]) {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _pump(tester, _FakeApi([_glow]), _Shared(), size: const Size(320, 640), locale: locale);

      await tester.scrollUntilVisible(find.byType(FactoryButton), 200);
      await tester.tap(find.byType(FactoryButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byIcon(Icons.check_circle_outline_rounded), 200);
      expect(tester.takeException(), isNull, reason: '$locale');
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget, reason: '$locale');
    }
  });

  testWidgets('Settings has a row that opens the backup screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salonAdminApiProvider.overrideWithValue(_FakeApi([_glow])),
          authControllerProvider.overrideWith(_Owner.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule and customers in an Excel file'), findsOneWidget);
    await tester.tap(find.text('Backup copy'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupScreen), findsOneWidget);
  });
}

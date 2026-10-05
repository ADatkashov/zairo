import 'package:business_admin/features/catalog/data/catalog_api.dart';
import 'package:business_admin/features/catalog/data/models/business_type.dart';
import 'package:business_admin/features/catalog/data/models/catalog_service.dart';
import 'package:business_admin/features/catalog/data/models/category.dart';
import 'package:business_admin/features/catalog/data/models/subsphere.dart';
import 'package:business_admin/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:business_admin/features/platform_admin/data/models/platform_admin_account_summary.dart';
import 'package:business_admin/features/platform_admin/data/models/platform_admin_session.dart';
import 'package:business_admin/features/platform_admin/data/models/platform_audit_log_entry.dart';
import 'package:business_admin/features/platform_admin/data/platform_admin_api.dart';
import 'package:business_admin/features/platform_admin/data/platform_business_api.dart';
import 'package:business_admin/features/platform_admin/presentation/platform_admin_labels.dart';
import 'package:business_admin/features/platform_admin/presentation/providers/platform_admin_providers.dart';
import 'package:business_admin/features/platform_admin/presentation/screens/platform_admin_console_screen.dart';
import 'package:business_admin/features/platform_admin/presentation/screens/platform_admin_login_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = PlatformAdminSession(
  accessToken: 'tok',
  email: 'boss@zairo.kz',
  displayName: 'Aida Boss',
  role: 'PLATFORM_ADMIN',
);

class _FakeSessionController extends PlatformAdminController {
  _FakeSessionController(this._initial);

  final PlatformAdminSession? _initial;

  @override
  Future<PlatformAdminSession?> build() async => _initial;

  @override
  Future<void> login({required String email, required String password}) async {
    state = AsyncData(_session);
  }
}

class _FakeBusinessApi extends PlatformBusinessApi {
  _FakeBusinessApi(this.businesses) : super(DioClient(Dio()));

  List<AdminProvider> businesses;
  final calls = <(String, String)>[];

  @override
  Future<List<AdminProvider>> list(String platformToken, {String? status}) async => businesses;

  @override
  Future<void> setStatus(String platformToken, String id, String status, {String? reason}) async {
    calls.add((id, status));
    businesses = [
      for (final b in businesses)
        if (b.id == id)
          AdminProvider(id: b.id, ownerUserId: b.ownerUserId, name: b.name, vertical: b.vertical, status: status)
        else
          b,
    ];
  }
}

class _FakeAdminApi extends PlatformAdminApi {
  _FakeAdminApi() : super(DioClient(Dio()));

  final deactivated = <String>[];

  @override
  Future<List<PlatformAdminAccountSummary>> listAdmins(String platformToken) async => const [
    PlatformAdminAccountSummary(
      id: 'a1',
      email: 'boss@zairo.kz',
      displayName: 'Aida Boss',
      role: 'PLATFORM_ADMIN',
      active: true,
    ),
    PlatformAdminAccountSummary(
      id: 'a2',
      email: 'mod@zairo.kz',
      displayName: 'Mara Mod',
      role: 'PLATFORM_MODERATOR',
      active: true,
    ),
  ];

  @override
  Future<PlatformAdminAccountSummary> deactivateAdmin(String platformToken, String adminId, {String? reason}) async {
    deactivated.add(adminId);
    return (await listAdmins(platformToken)).firstWhere((a) => a.id == adminId);
  }

  @override
  Future<List<PlatformAuditLogEntry>> auditLog(String platformToken, {int size = 50}) async => [
    PlatformAuditLogEntry(
      id: 'e1',
      actorEmail: 'boss@zairo.kz',
      action: 'PROVIDER_STATUS_CHANGED',
      previousValue: 'PENDING',
      newValue: 'ACTIVE',
      createdAt: DateTime(2026, 10, 5, 10, 30),
    ),
  ];
}

class _FakeCatalogApi extends CatalogApi {
  _FakeCatalogApi() : super(DioClient(Dio()));

  final createdCategories = <Map<String, Object?>>[];
  final statusChanges = <(String, String)>[];

  @override
  Future<List<Category>> listAllCategories(String platformToken) async => [
    const Category(
      id: 'c1',
      code: 'beauty',
      nameKk: 'Сұлулық',
      nameRu: 'Красота',
      nameEn: 'Beauty',
      icon: '💅',
      sortOrder: 1,
      status: 'ACTIVE',
    ),
  ];

  @override
  Future<List<BusinessType>> listAllBusinessTypes(String platformToken, String categoryId) async => [];

  @override
  Future<List<Subsphere>> listAllSubspheres(String platformToken, String businessTypeId) async => [];

  @override
  Future<List<CatalogServiceModel>> listAllCatalogServices(String platformToken, String businessTypeId) async => [];

  @override
  Future<Category> createCategory(
    String platformToken, {
    required String code,
    required String nameKk,
    required String nameRu,
    required String nameEn,
    String? icon,
    required int sortOrder,
  }) async {
    createdCategories.add({'code': code, 'nameEn': nameEn, 'nameRu': nameRu, 'nameKk': nameKk});
    return Category(
      id: 'c2',
      code: code,
      nameKk: nameKk,
      nameRu: nameRu,
      nameEn: nameEn,
      icon: icon,
      sortOrder: sortOrder,
      status: 'ACTIVE',
    );
  }

  @override
  Future<void> setCategoryStatus(String platformToken, String id, String status) async {
    statusChanges.add((id, status));
  }
}

const _pending = AdminProvider(id: 'p1', ownerUserId: 'o1', name: 'Glow Salon', vertical: 'beauty', status: 'PENDING');
const _active = AdminProvider(id: 'p2', ownerUserId: 'o2', name: 'Zen Spa', vertical: 'beauty', status: 'ACTIVE');

Future<void> _pump(
  WidgetTester tester, {
  PlatformAdminSession? session = _session,
  Locale locale = const Locale('en'),
  required _FakeBusinessApi businessApi,
  _FakeAdminApi? adminApi,
  _FakeCatalogApi? catalogApi,
  Widget home = const PlatformAdminConsoleScreen(),
  Size size = const Size(900, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformAdminControllerProvider.overrideWith(() => _FakeSessionController(session)),
        platformBusinessApiProvider.overrideWithValue(businessApi),
        platformAdminApiProvider.overrideWithValue(adminApi ?? _FakeAdminApi()),
        catalogApiProvider.overrideWithValue(catalogApi ?? _FakeCatalogApi()),
      ],
      child: MaterialApp(
        theme: factoryLightTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('labels', () {
    test('slugifyCode builds a valid code from an English name', () {
      expect(slugifyCode('Hot Yoga!'), 'hot_yoga');
      expect(slugifyCode('  Nail  art & care '), 'nail_art_care');
      expect(isValidCatalogCode('hot_yoga'), isTrue);
      expect(isValidCatalogCode('Hot Yoga'), isFalse);
    });

    test('humanizeCode makes an unknown code readable', () {
      expect(humanizeCode('SOME_NEW_ACTION'), 'Some new action');
    });
  });

  testWidgets('businesses: shows readable statuses, pending banner and approves in one tap', (tester) async {
    final businessApi = _FakeBusinessApi([_active, _pending]);
    await _pump(tester, businessApi: businessApi);

    // Raw codes never leak into the UI.
    expect(find.text('PENDING'), findsNothing);
    expect(find.text('PLATFORM_ADMIN'), findsNothing);
    expect(find.text('1 business is waiting for approval'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsWidgets);

    // Pending business is listed first.
    expect(tester.getTopLeft(find.text('Glow Salon')).dy, lessThan(tester.getTopLeft(find.text('Zen Spa')).dy));

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(businessApi.calls, [('p1', 'ACTIVE')]);
    expect(find.text('Glow Salon approved'), findsOneWidget);
    expect(find.textContaining('waiting for approval'), findsNothing);
  });

  testWidgets('businesses: suspending asks for confirmation first', (tester) async {
    final businessApi = _FakeBusinessApi([_active]);
    await _pump(tester, businessApi: businessApi);

    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(find.text('Suspend Zen Spa?'), findsOneWidget);
    expect(businessApi.calls, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(businessApi.calls, isEmpty);

    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Suspend'));
    await tester.pumpAndSettle();
    expect(businessApi.calls, [('p2', 'SUSPENDED')]);
  });

  testWidgets('businesses: search narrows the list and an empty result says so', (tester) async {
    await _pump(tester, businessApi: _FakeBusinessApi([_active, _pending]));

    await tester.enterText(find.byType(TextField).first, 'zen');
    await tester.pumpAndSettle();
    expect(find.text('Zen Spa'), findsOneWidget);
    expect(find.text('Glow Salon'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'nope');
    await tester.pumpAndSettle();
    expect(find.text('No businesses match your search or filter.'), findsOneWidget);
  });

  testWidgets('a support account sees businesses but no action buttons, and no Staff tab', (tester) async {
    await _pump(
      tester,
      session: const PlatformAdminSession(
        accessToken: 'tok',
        email: 'help@zairo.kz',
        displayName: 'Help Desk',
        role: 'PLATFORM_SUPPORT',
      ),
      businessApi: _FakeBusinessApi([_pending]),
    );
    expect(find.text('Glow Salon'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Suspend'), findsNothing);
    expect(find.text('Staff'), findsNothing);
  });

  testWidgets('console is translated: Russian shows no English tab names', (tester) async {
    await _pump(tester, locale: const Locale('ru'), businessApi: _FakeBusinessApi([_pending]));
    expect(find.text('Консоль платформы'), findsOneWidget);
    expect(find.text('Ждёт одобрения'), findsWidgets);
    expect(find.text('Одобрить'), findsOneWidget);
    expect(find.text('Businesses'), findsNothing);
  });

  testWidgets('catalog: new category fills the code from the name and saves', (tester) async {
    final catalogApi = _FakeCatalogApi();
    await _pump(tester, businessApi: _FakeBusinessApi([]), catalogApi: catalogApi);

    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();
    expect(find.text('💅 Beauty'), findsOneWidget);

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();

    // Submitting empty shows per-field hints rather than a generic error.
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name (English)'), 'Hot Yoga');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Russian)'), 'Хот-йога');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (Kazakh)'), 'Хот-йога');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'hot_yoga'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(catalogApi.createdCategories.single['code'], 'hot_yoga');
    expect(find.text('Hot Yoga created'), findsOneWidget);
  });

  testWidgets('catalog: hiding an item asks first, showing it again does not', (tester) async {
    final catalogApi = _FakeCatalogApi();
    await _pump(tester, businessApi: _FakeBusinessApi([]), catalogApi: catalogApi);
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Hide 💅 Beauty?'), findsOneWidget);
    expect(catalogApi.statusChanges, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await tester.pumpAndSettle();
    expect(catalogApi.statusChanges, [('c1', 'INACTIVE')]);
  });

  testWidgets('activity log speaks in words, not codes', (tester) async {
    await _pump(tester, businessApi: _FakeBusinessApi([]));
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Business status changed'), findsOneWidget);
    expect(find.text('by boss@zairo.kz'), findsOneWidget);
    expect(find.text('Awaiting approval → Active'), findsOneWidget);
    expect(find.text('PROVIDER_STATUS_CHANGED'), findsNothing);
  });

  testWidgets('staff: roles are named, you cannot deactivate yourself, deactivating asks first', (tester) async {
    final adminApi = _FakeAdminApi();
    await _pump(tester, businessApi: _FakeBusinessApi([]), adminApi: adminApi);
    await tester.tap(find.text('Staff'));
    await tester.pumpAndSettle();

    expect(find.text('You'), findsOneWidget);
    expect(find.textContaining('Moderator'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget); // only Mara's row

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Mara Mod?'), findsOneWidget);
    expect(adminApi.deactivated, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();
    expect(adminApi.deactivated, ['a2']);
  });

  testWidgets('signing out asks for confirmation', (tester) async {
    await _pump(
      tester,
      businessApi: _FakeBusinessApi([]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlatformAdminConsoleScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aida Boss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of the console?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminConsoleScreen), findsOneWidget);

    // Confirming signs out and leaves the console.
    await tester.tap(find.byTooltip('Aida Boss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminConsoleScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('login screen signs in and shows the console in place', (tester) async {
    await _pump(
      tester,
      session: null,
      businessApi: _FakeBusinessApi([_active]),
      home: const PlatformAdminLoginScreen(),
    );
    expect(find.textContaining('platform staff account'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boss@zairo.kz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(PlatformAdminConsoleScreen), findsOneWidget);
    expect(find.text('Zen Spa'), findsOneWidget);
  });

  for (final locale in const ['en', 'ru', 'kk']) {
    testWidgets('every tab fits a 360px phone without overflow ($locale)', (tester) async {
      // A tab that sits off-screen would make tap() miss — treat that as a failure.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await _pump(
        tester,
        locale: Locale(locale),
        size: const Size(360, 740),
        businessApi: _FakeBusinessApi([_pending, _active]),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(PlatformAdminConsoleScreen)))!;
      for (final tab in [l10n.paTabCatalog, l10n.paTabActivity, l10n.paTabStaff, l10n.paTabBusinesses]) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
      }
      // Open the create dialog on the catalog tab, too.
      await tester.tap(find.text(l10n.paTabCatalog).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.paAddCategory));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

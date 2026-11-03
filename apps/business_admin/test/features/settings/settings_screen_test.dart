import 'package:business_admin/app/locale/locale_controller.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/settings/presentation/screens/settings_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : super(const FlutterSecureStorage());

  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

/// Mirrors app.dart's exact locale wiring (localeControllerProvider ->
/// MaterialApp.locale) around just SettingsScreen, instead of the full
/// BusinessAdminApp — keeps this test focused on the locale-switching
/// behavior without pulling in routing/auth.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider).value;
    return MaterialApp(
      // The real app always runs on the Factory theme; the settings cards read it.
      theme: factoryLightTheme(profile: FactoryAppProfile.business),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SettingsScreen(),
    );
  }
}

class _SignedInController extends AuthController {
  bool loggedOut = false;

  @override
  Future<UserSummary?> build() async =>
      const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AsyncValue.data(null);
  }
}

void main() {
  testWidgets('signed in, Settings has Log out: it asks first, and Stay keeps the session', (tester) async {
    final controller = _SignedInController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
          authControllerProvider.overrideWith(() => controller),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Stay signed in'), findsOneWidget);

    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(controller.loggedOut, isFalse);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FactoryButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(controller.loggedOut, isTrue);
  });

  testWidgets('signed out, Settings has no Log out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService())],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('hides the Subscription row while signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService())],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Subscription'), findsNothing);
  });

  testWidgets(
    'defaults to system language and switches to Kazakh, persisting the choice',
    (tester) async {
      final storage = _InMemorySecureStorageService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // No override stored yet -> follows the test environment's locale (en).
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Қазақша'));
      await tester.pumpAndSettle();

      // The whole app re-renders in Kazakh, not just the picker's own subtitle.
      expect(find.text('Баптаулар'), findsOneWidget);
      expect(find.text('Қазақша'), findsOneWidget);
      expect(await storage.read('locale_code'), 'kk');
    },
  );

  testWidgets('picking "System default" clears a previously stored override', (
    tester,
  ) async {
    final storage = _InMemorySecureStorageService();
    await storage.write('locale_code', 'ru');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);

    await tester.tap(find.text('Язык'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Как в системе'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(await storage.read('locale_code'), isNull);
  });

  testWidgets(
    'switching to dark mode persists it, and a fresh app instance restores it',
    (tester) async {
      final storage = _InMemorySecureStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      // No override stored yet -> the provider's own ThemeMode.system default.
      expect(find.text('Current theme: System'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.text('Current theme: Dark'), findsOneWidget);
      expect(await storage.read('theme_mode'), 'dark');

      // A fresh ProviderScope simulates a cold app restart against the same
      // backing storage — the whole point of persisting the choice.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [secureStorageServiceProvider.overrideWithValue(storage)],
          child: const _TestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current theme: Dark'), findsOneWidget);
    },
  );
}

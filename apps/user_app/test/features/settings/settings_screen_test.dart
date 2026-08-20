import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/app/locale/locale_controller.dart';
import 'package:zairo/features/settings/presentation/screens/settings_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

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
/// ZairoApp — keeps this test focused on the locale-switching behavior
/// without pulling in routing/networking.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider).value;
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SettingsScreen(),
    );
  }
}

void main() {
  testWidgets('defaults to system language and switches to Kazakh, persisting the choice', (tester) async {
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
  });

  testWidgets('picking "System default" clears a previously stored override', (tester) async {
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
}

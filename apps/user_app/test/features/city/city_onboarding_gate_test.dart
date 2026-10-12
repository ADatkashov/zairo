import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zairo/features/city/data/models/city.dart';
import 'package:zairo/features/city/presentation/providers/city_providers.dart';
import 'package:zairo/features/city/presentation/widgets/city_onboarding_gate.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage([Map<String, String>? initial])
    : values = {...?initial},
      super(const FlutterSecureStorage());

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Future<_MemoryStorage> _pump(
  WidgetTester tester, {
  required City? city,
  Map<String, String>? stored,
  bool showWelcome = false,
}) async {
  final storage = _MemoryStorage(stored);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        userCurrentCityProvider.overrideWith((ref) async => city),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => CityOnboardingGate(showWelcome: showWelcome, child: const Scaffold(body: Text('home'))),
            ),
            GoRoute(
              path: '/welcome',
              builder: (context, _) => Scaffold(
                body: TextButton(onPressed: () => context.pop(), child: const Text('welcome page')),
              ),
            ),
            GoRoute(path: '/city-selection', builder: (_, _) => const Scaffold(body: Text('pick a city'))),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

final _almaty = City(
  code: 'almaty',
  name: 'Almaty',
  countryCode: 'KZ',
  timezone: 'Asia/Almaty',
  currency: 'KZT',
  active: true,
);

void main() {
  testWidgets('first launch with no known city opens the city picker once', (tester) async {
    final storage = await _pump(tester, city: null);

    expect(find.text('pick a city'), findsOneWidget);
    expect(storage.values[cityOnboardingDoneKey], '1');
  });

  testWidgets('a known city is never prompted for', (tester) async {
    final storage = await _pump(tester, city: _almaty);

    expect(find.text('home'), findsOneWidget);
    expect(find.text('pick a city'), findsNothing);
    expect(storage.values[cityOnboardingDoneKey], '1');
  });

  testWidgets('after the first launch the picker is not offered again', (tester) async {
    await _pump(tester, city: null, stored: {cityOnboardingDoneKey: '1'});

    expect(find.text('home'), findsOneWidget);
    expect(find.text('pick a city'), findsNothing);
  });

  testWidgets('with the welcome on, the first launch shows it first and the city picker after it', (tester) async {
    final storage = await _pump(tester, city: null, showWelcome: true);

    expect(find.text('welcome page'), findsOneWidget);
    expect(find.text('pick a city'), findsNothing);
    expect(storage.values[welcomeDoneKey], '1');

    await tester.tap(find.text('welcome page'));
    await tester.pumpAndSettle();

    expect(find.text('pick a city'), findsOneWidget);
    expect(storage.values[cityOnboardingDoneKey], '1');
  });

  testWidgets('the welcome is shown once: a second launch skips straight to the normal flow', (tester) async {
    await _pump(tester, city: _almaty, showWelcome: true, stored: {welcomeDoneKey: '1'});

    expect(find.text('welcome page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an existing user who just updated does not get the welcome', (tester) async {
    // They already went through the city prompt on an older version.
    final storage = await _pump(tester, city: null, showWelcome: true, stored: {cityOnboardingDoneKey: '1'});

    expect(find.text('welcome page'), findsNothing);
    expect(find.text('pick a city'), findsNothing);
    expect(storage.values[welcomeDoneKey], '1');
  });

  testWidgets('the welcome stays off for callers that do not ask for it', (tester) async {
    await _pump(tester, city: _almaty);

    expect(find.text('welcome page'), findsNothing);
  });
}

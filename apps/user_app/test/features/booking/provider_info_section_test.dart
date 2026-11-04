import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/presentation/widgets/provider_info_section.dart';
import 'package:zairo/features/discovery/data/models/provider_search_result.dart';
import 'package:zairo/l10n/app_localizations.dart';

ProviderSearchResult _provider({
  String? address,
  String? phone,
  String? description,
  Map<String, String> hours = const {},
  double? lat,
  double? lng,
}) => ProviderSearchResult(
  id: 'p1',
  name: 'Salon',
  vertical: 'beauty',
  status: 'ACTIVE',
  hasOpenAvailability: true,
  services: const [],
  address: address,
  phone: phone,
  description: description,
  workingHours: hours,
  latitude: lat,
  longitude: lng,
);

// 2024-01-01 is a Monday.
Widget _app(ProviderSearchResult p, {DateTime? now}) => MaterialApp(
  theme: factoryLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: SingleChildScrollView(
      child: ProviderInfoSection(
        provider: p,
        now: () => now ?? DateTime(2024, 1, 1, 12),
      ),
    ),
  ),
);

void main() {
  const hours = {'mon': '09:00-20:00', 'sat': '10:00-16:00'};

  testWidgets('renders nothing when the owner filled in nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_provider()));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('open now shows the closing time, a tap lists the whole week', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_provider(hours: hours)));
    expect(find.text('Open until 20:00'), findsOneWidget);
    expect(find.text('Working hours'), findsNothing);

    await tester.tap(find.text('Open until 20:00'));
    await tester.pump();
    expect(find.text('09:00–20:00'), findsOneWidget);
    expect(find.text('10:00–16:00'), findsOneWidget);
    expect(find.text('Closed'), findsNWidgets(5));
  });

  testWidgets('closed says when it opens: tomorrow, later today, another day', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_provider(hours: hours), now: DateTime(2024, 1, 1, 21)),
    );
    expect(find.text('Closed · opens Sat at 10:00'), findsOneWidget);

    await tester.pumpWidget(
      _app(_provider(hours: hours), now: DateTime(2024, 1, 1, 7)),
    );
    expect(find.text('Closed · opens at 09:00'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        _provider(hours: const {'mon': '09:00-20:00', 'tue': '09:00-20:00'}),
        now: DateTime(2024, 1, 1, 21),
      ),
    );
    expect(find.text('Closed · opens tomorrow at 09:00'), findsOneWidget);
  });

  testWidgets('address, description and call/directions actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _provider(
          address: 'Abay 10',
          phone: '+7 701 000 00 00',
          description: 'Cosy place',
          lat: 43.2,
          lng: 76.9,
        ),
      ),
    );
    expect(find.text('Abay 10'), findsOneWidget);
    expect(find.text('Cosy place'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    // No hours stated: no status row.
    expect(find.textContaining('Open until'), findsNothing);
  });

  testWidgets('no phone and no coordinates -> no action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_provider(address: 'Abay 10')));
    expect(find.text('Call'), findsNothing);
    expect(find.text('Directions'), findsNothing);
  });

  testWidgets('a long description collapses and expands', (tester) async {
    final long = 'Word ' * 60;
    await tester.pumpWidget(_app(_provider(description: long.trim())));
    expect(find.text('More'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pump();
    expect(find.text('Less'), findsOneWidget);
    await tester.tap(find.text('Less'));
    await tester.pump();
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('a short description has no toggle', (tester) async {
    await tester.pumpWidget(_app(_provider(description: 'Short')));
    expect(find.text('More'), findsNothing);
  });

  test('the model parses the profile fields and defaults them', () {
    final parsed = ProviderSearchResult.fromJson({
      'id': 'p',
      'name': 'n',
      'vertical': 'beauty',
      'status': 'ACTIVE',
      'hasOpenAvailability': false,
      'services': <dynamic>[],
      'address': 'A',
      'phone': '1',
      'description': 'D',
      'workingHours': {'mon': '09:00-10:00'},
    });
    expect(parsed.address, 'A');
    expect(parsed.workingHours, {'mon': '09:00-10:00'});
    final bare = ProviderSearchResult.fromJson({
      'id': 'p',
      'name': 'n',
      'vertical': 'beauty',
      'status': 'ACTIVE',
      'hasOpenAvailability': false,
      'services': <dynamic>[],
    });
    expect(bare.address, isNull);
    expect(bare.workingHours, isEmpty);
  });
}

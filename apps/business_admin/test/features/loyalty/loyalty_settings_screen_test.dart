import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/loyalty/data/api/loyalty_admin_api.dart';
import 'package:business_admin/features/loyalty/data/models/loyalty_settings.dart';
import 'package:business_admin/features/loyalty/presentation/providers/loyalty_admin_providers.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_settings_screen.dart';
import 'package:business_admin/l10n/app_localizations.dart';

const _providerId = 'provider-1';

LoyaltySettings _draftSettings({bool enabled = false}) => LoyaltySettings(
      providerId: _providerId,
      enabled: enabled,
      name: 'Loyalty Rewards',
      fixedPointsPerBooking: 10,
      pointsPerCurrencyUnit: 0,
      firstBookingBonusPoints: 0,
      repeatVisitBonusPoints: 0,
      repeatVisitThreshold: 2,
      reviewBonusPoints: 0,
      pointsExpireEnabled: false,
    );

class _FakeLoyaltyAdminApi extends LoyaltyAdminApi {
  _FakeLoyaltyAdminApi({LoyaltySettings? settings}) : _settings = settings ?? _draftSettings(), super(DioClient(Dio()));

  LoyaltySettings _settings;
  Object? fetchError;
  LoyaltySettings? lastUpdate;

  @override
  Future<LoyaltySettings> fetchSettings(String providerId) async {
    if (fetchError != null) throw fetchError!;
    return _settings;
  }

  @override
  Future<LoyaltySettings> updateSettings(String providerId, LoyaltySettings settings) async {
    lastUpdate = settings;
    _settings = settings;
    return settings;
  }
}

Widget _wrap(_FakeLoyaltyAdminApi api) => ProviderScope(
      overrides: [loyaltyAdminApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LoyaltySettingsScreen(providerId: _providerId)),
      ),
    );

void main() {
  testWidgets('shows the enable switch off and the program name once settings load', (tester) async {
    final api = _FakeLoyaltyAdminApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    expect(find.text('Loyalty Rewards'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when settings fail to load', (tester) async {
    final api = _FakeLoyaltyAdminApi()..fetchError = Exception('network down');
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load loyalty settings"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('toggling enable and saving sends the full update payload', (tester) async {
    final api = _FakeLoyaltyAdminApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    // The form is long enough that the Save button starts outside the
    // default test viewport's cache extent (a plain ListView only mounts
    // elements near what's visible) -- scroll it into view first, same
    // fix the campaigns feature's own tests use for a tall screen.
    final saveButtonFinder = find.widgetWithText(FactoryButton, 'Save');
    await tester.scrollUntilVisible(saveButtonFinder, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(saveButtonFinder);
    await tester.pumpAndSettle();

    expect(api.lastUpdate, isNotNull);
    expect(api.lastUpdate!.enabled, isTrue);
    expect(api.lastUpdate!.name, 'Loyalty Rewards');
    expect(find.text('Loyalty settings saved.'), findsOneWidget);
  });
}

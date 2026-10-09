import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/auth/data/models/user_summary.dart';
import 'package:business_admin/features/auth/presentation/providers/auth_providers.dart';
import 'package:business_admin/features/billing/data/billing_api.dart';
import 'package:business_admin/features/billing/data/models/payment_method.dart';
import 'package:business_admin/features/billing/data/models/subscription.dart';
import 'package:business_admin/features/billing/data/models/subscription_charge.dart';
import 'package:business_admin/features/billing/presentation/providers/billing_providers.dart';
import 'package:business_admin/features/billing/presentation/screens/billing_screen.dart';
import 'package:business_admin/features/salon/data/models/admin_provider.dart';
import 'package:business_admin/features/salon/data/salon_admin_api.dart';
import 'package:business_admin/features/salon/presentation/providers/salon_providers.dart';
import 'package:business_admin/l10n/app_localizations.dart';

class _FakeBillingApi extends BillingApi {
  _FakeBillingApi(this._subscription) : super(DioClient(Dio()));

  Subscription _subscription;
  bool upgradeCalled = false;
  bool cardRemoved = false;

  /// When set, upgrade leaves the plan alone and hands back this checkout URL, like a redirect-based provider.
  String? checkoutUrl;
  PaymentMethod paymentMethod = const PaymentMethod(
    saved: true,
    brand: 'VISA',
    last4: '4242',
    autoRenew: true,
  );

  /// Stands in for the provider's webhook arriving while the owner pays in the browser.
  void confirmPayment() => _subscription = _free.copyWith(plan: 'PRO');

  @override
  Future<PaymentMethod> getPaymentMethod() async => paymentMethod;

  @override
  Future<void> removePaymentMethod() async {
    cardRemoved = true;
    paymentMethod = const PaymentMethod(saved: false, autoRenew: false);
  }

  @override
  Future<Subscription> getMine() async => _subscription;

  @override
  Future<Subscription> upgradeToPro() async {
    upgradeCalled = true;
    final url = checkoutUrl;
    if (url != null) {
      return _free.withCheckoutUrl(url);
    }
    _subscription = _free.copyWith(plan: 'PRO');
    return _subscription;
  }

  @override
  Future<List<SubscriptionCharge>> listCharges() async => const [];
}

final _free = Subscription(
  id: 'sub-1',
  ownerUserId: 'owner-1',
  plan: 'FREE',
  status: 'ACTIVE',
  limits: PlanLimits(maxProviders: 1, maxStaffPerProvider: 3, maxBookingsPerMonth: 30, recurringScheduleAllowed: false),
  currentPeriodStart: _periodStart,
  currentPeriodEnd: _periodEnd,
  cancelAtPeriodEnd: false,
  proMonthlyPrice: 29,
  currency: 'KZT',
);

final _periodStart = DateTime(2026, 1, 1);
final _periodEnd = DateTime(2026, 2, 1);

extension on Subscription {
  Subscription withCheckoutUrl(String url) => Subscription(
        id: id,
        ownerUserId: ownerUserId,
        plan: plan,
        status: status,
        limits: limits,
        currentPeriodStart: currentPeriodStart,
        currentPeriodEnd: currentPeriodEnd,
        cancelAtPeriodEnd: cancelAtPeriodEnd,
        checkoutUrl: url,
      );

  Subscription copyWith({String? plan}) => Subscription(
        id: id,
        ownerUserId: ownerUserId,
        plan: plan ?? this.plan,
        status: status,
        limits: plan == 'PRO'
            ? const PlanLimits(
                maxProviders: 5, maxStaffPerProvider: 20, maxBookingsPerMonth: 2147483647, recurringScheduleAllowed: true)
            : limits,
        currentPeriodStart: currentPeriodStart,
        currentPeriodEnd: currentPeriodEnd,
        cancelAtPeriodEnd: cancelAtPeriodEnd,
      );
}

class _FakeSalonAdminApi extends SalonAdminApi {
  _FakeSalonAdminApi() : super(DioClient(Dio()));

  @override
  Future<List<AdminProvider>> listMyProviders(String ownerUserId) async => const [];
}

class _LoggedInOwnerController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'owner-1', email: 'owner@example.com', displayName: 'Jamie Owner', role: 'PROVIDER_OWNER');
  }
}

void main() {
  testWidgets('shows the FREE plan, its limits, and an upgrade button', (tester) async {
    final fakeApi = _FakeBillingApi(_free);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FREE plan'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('up to 3'), findsOneWidget);
    expect(find.text('up to 30'), findsOneWidget);
    expect(find.text('PRO only'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upgrade to PRO'), findsOneWidget);
    // The price comes from the server's response, not a literal in the screen.
    final price = tester.widget<FactoryPriceText>(find.byType(FactoryPriceText));
    expect(price.amount, 29);
    expect(price.currencySymbol, 'KZT');
  });

  testWidgets('tapping upgrade calls the API and refreshes to show PRO', (tester) async {
    final fakeApi = _FakeBillingApi(_free);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInOwnerController.new),
          salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BillingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade to PRO'));
    await tester.pumpAndSettle();

    expect(fakeApi.upgradeCalled, isTrue);
    expect(find.text('PRO plan'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Downgrade to FREE'), findsOneWidget);
  });

  testWidgets('a PRO owner sees the saved card and can remove it', (tester) async {
    final fakeApi = _FakeBillingApi(_free.copyWith(plan: 'PRO'));

    await tester.pumpWidget(_app(fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('VISA •••• 4242'), findsOneWidget);
    expect(find.textContaining('Renews automatically on'), findsOneWidget);

    await tester.tap(find.text('Remove card'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this card?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(fakeApi.cardRemoved, isTrue);
    expect(find.text('VISA •••• 4242'), findsNothing);
    expect(find.textContaining('No saved card'), findsOneWidget);
  });

  testWidgets('a card that cannot be charged automatically says renewals are paid on the payment page', (tester) async {
    final fakeApi = _FakeBillingApi(_free.copyWith(plan: 'PRO'))
      ..paymentMethod = const PaymentMethod(saved: true, brand: 'VISA', last4: '1111', autoRenew: false);

    await tester.pumpWidget(_app(fakeApi));
    await tester.pumpAndSettle();

    expect(find.textContaining('Each renewal is paid on the payment page'), findsOneWidget);
    expect(find.textContaining('Renews automatically on'), findsNothing);
  });

  testWidgets('upgrading through a checkout page opens it and waits for the server to confirm PRO', (tester) async {
    final fakeApi = _FakeBillingApi(_free)..checkoutUrl = 'https://pay.example/checkout/1';
    final opened = <Uri>[];

    await tester.pumpWidget(
      _app(
        fakeApi,
        extraOverrides: [
          billingCheckoutLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
          billingPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 200)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade to PRO'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(opened, [Uri.parse('https://pay.example/checkout/1')]);
    expect(find.text('Waiting for payment confirmation…'), findsOneWidget);
    expect(find.text('FREE plan'), findsOneWidget);

    // The provider's webhook lands; the next poll picks it up.
    fakeApi.confirmPayment();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('PRO plan'), findsOneWidget);
    expect(find.text('Waiting for payment confirmation…'), findsNothing);
  });

  testWidgets('if the payment page cannot be opened, an error is shown and nothing is awaited', (tester) async {
    final fakeApi = _FakeBillingApi(_free)..checkoutUrl = 'https://pay.example/checkout/2';

    await tester.pumpWidget(
      _app(fakeApi, extraOverrides: [billingCheckoutLauncherProvider.overrideWithValue((uri) async => false)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade to PRO'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't open the payment page"), findsOneWidget);
    expect(find.text('Waiting for payment confirmation…'), findsNothing);
  });
}

Widget _app(_FakeBillingApi fakeApi, {List<Override> extraOverrides = const []}) {
  return ProviderScope(
    overrides: [
      billingApiProvider.overrideWithValue(fakeApi),
      authControllerProvider.overrideWith(_LoggedInOwnerController.new),
      salonAdminApiProvider.overrideWithValue(_FakeSalonAdminApi()),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BillingScreen(),
    ),
  );
}

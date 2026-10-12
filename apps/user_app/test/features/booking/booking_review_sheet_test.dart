import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/booking/data/models/payment_plan.dart';
import 'package:zairo/features/booking/presentation/widgets/booking_review_sheet.dart';
import 'package:zairo/features/booking/presentation/widgets/booking_stepper.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: factoryLightTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

BookingReviewData _data({PaymentPlan? plan, String? personName}) => BookingReviewData(
  providerName: 'Studio Nova',
  serviceTitle: 'Haircut',
  durationMinutes: 60,
  price: 6000,
  currencySymbol: '₸',
  startsAt: DateTime(2026, 3, 14, 15, 30),
  personName: personName,
  plan: plan,
);

Future<bool?> _open(WidgetTester tester, BookingReviewData data) async {
  bool? result;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showBookingReviewSheet(context, data),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('the stepper reads as "Step N of 3" and marks finished steps with a check', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: BookingStepper(step: 1))));
    expect(find.bySemanticsLabel('Step 2 of 3: Time'), findsOneWidget);
    // One finished step: its number is replaced by a check.
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(_app(const Scaffold(body: BookingStepper(step: 2))));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 3 of 3: Payment'), findsOneWidget);
  });

  testWidgets('with a deposit the sheet shows what is paid now and offers to pay', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester, _data(plan: PaymentPlan.fromAmounts(total: 6000, deposit: 1800), personName: 'Aigerim K.'));
    expect(find.text('Check your booking'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('Studio Nova'), findsOneWidget);
    expect(find.widgetWithText(FactoryButton, 'Confirm and pay'), findsOneWidget);
  });

  testWidgets('with nothing due now or an unknown policy the button does not talk about paying', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester, _data(plan: PaymentPlan.fromAmounts(total: 6000, deposit: 0), personName: ''));
    expect(find.text('First available'), findsOneWidget);
    expect(find.widgetWithText(FactoryButton, 'Confirm booking'), findsOneWidget);

    await tester.tap(find.widgetWithText(FactoryButton, 'Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  });

  testWidgets('the sheet fits a small phone in Russian and Kazakh', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final code in ['ru', 'kk']) {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showBookingReviewSheet(
                  context,
                  _data(plan: PaymentPlan.fromAmounts(total: 6000, deposit: 1800), personName: 'Айгерим Касымова'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          locale: Locale(code),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: code);
      expect(result, isNull);
      Navigator.of(tester.element(find.byType(FactoryBottomSheet))).pop(false);
      await tester.pumpAndSettle();
    }
  });
}

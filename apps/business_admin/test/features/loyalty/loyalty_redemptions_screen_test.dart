import 'package:business_admin/features/loyalty/data/models/loyalty_redemption.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_redemptions_screen.dart';
import 'package:business_admin/features/loyalty/presentation/widgets/loyalty_redemption_card.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _list = '/business/p1/loyalty/redemptions';

Map<String, Object?> _redemption(String id, String status, {String? appliedBookingId}) => {
      'id': id,
      'userId': 'u1',
      'rewardId': 'r1',
      'rewardName': 'Reward $id',
      'pointsSpent': 300,
      'code': 'CODE-$id',
      'status': status,
      'createdAt': '2026-10-12T10:00:00Z',
      'appliedBookingId': appliedBookingId,
    };

Map<String, Object?> _page(List<Map<String, Object?>> content, {int number = 0, int totalPages = 1}) => {
      'content': content,
      'totalElements': content.length,
      'totalPages': totalPages,
      'number': number,
      'size': 20,
      'first': number == 0,
      'last': number == totalPages - 1,
    };

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const Scaffold(body: LoyaltyRedemptionsScreen(providerId: 'p1'))));
  await tester.pumpAndSettle();
}

FakeHttp _backend([List<Map<String, Object?>>? items]) {
  final http = FakeHttp();
  http.reply('GET', _list, _page(items ?? [_redemption('1', 'ACTIVE')]));
  return http;
}

Finder get _apply => find.widgetWithText(FloatingActionButton, en.loyaltyRedemptionApplyButton);
Finder _inDialog(Finder finder) => find.descendant(of: find.byType(Dialog), matching: finder);

void main() {
  group('list', () {
    testWidgets('an empty programme says there are no redemptions yet', (tester) async {
      await _open(tester, _backend([]));

      expect(find.text(en.loyaltyRedemptionsEmpty), findsOneWidget);
      expect(find.byType(LoyaltyRedemptionCard), findsNothing);
      expect(_apply, findsOneWidget);
    });

    testWidgets('each redemption shows its reward, code, status and points', (tester) async {
      await _open(tester, _backend([
        _redemption('1', 'ACTIVE'),
        _redemption('2', 'APPLIED', appliedBookingId: 'b-9'),
        _redemption('3', 'CANCELLED'),
        _redemption('4', 'EXPIRED'),
      ]));

      expect(find.byType(LoyaltyRedemptionCard), findsNWidgets(4));
      expect(find.text('Reward 1'), findsOneWidget);
      expect(find.text('CODE-2'), findsOneWidget);
      for (final status in LoyaltyRedemptionStatus.values) {
        expect(find.text(loyaltyRedemptionStatusLabel(en, status)), findsOneWidget, reason: status.name);
      }
      expect(find.text(en.loyaltyRedemptionPointsSpentLabel(300)), findsNWidgets(4));
      expect(find.text(en.loyaltyRedemptionAppliedBookingLabel('b-9')), findsOneWidget);
    });

    testWidgets('only an active redemption can be cancelled', (tester) async {
      await _open(tester, _backend([_redemption('1', 'ACTIVE'), _redemption('2', 'APPLIED'), _redemption('3', 'EXPIRED')]));

      expect(find.widgetWithText(FactoryButton, en.loyaltyRedemptionCancelButton), findsOneWidget);
    });

    testWidgets('each status has its own badge style', (tester) async {
      expect(loyaltyRedemptionStatusVariant(LoyaltyRedemptionStatus.active), FactoryBadgeVariant.available);
      expect(loyaltyRedemptionStatusVariant(LoyaltyRedemptionStatus.applied), FactoryBadgeVariant.verified);
      expect(loyaltyRedemptionStatusVariant(LoyaltyRedemptionStatus.cancelled), FactoryBadgeVariant.neutral);
      expect(loyaltyRedemptionStatusVariant(LoyaltyRedemptionStatus.expired), FactoryBadgeVariant.error);
    });

    testWidgets('a list that fails to load shows an error and retrying loads it', (tester) async {
      final http = _backend();
      http.fail('GET', _list, 500);
      await _open(tester, http);
      expect(find.text(en.errorLoyaltyRedemptionsLoadFailed), findsOneWidget);

      http.reply('GET', _list, _page([_redemption('1', 'ACTIVE')]));
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorLoyaltyRedemptionsLoadFailed), findsNothing);
      expect(find.text('Reward 1'), findsOneWidget);
    });

    testWidgets('a long list loads more on request and stops at the last page', (tester) async {
      final http = FakeHttp();
      http.reply('GET', _list, _page([_redemption('1', 'ACTIVE')], totalPages: 2));
      await _open(tester, http);
      expect(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore), findsOneWidget);
      expect(find.text('Reward 2'), findsNothing);

      http.reply('GET', _list, _page([_redemption('2', 'APPLIED')], number: 1, totalPages: 2));
      await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore));
      await tester.pumpAndSettle();

      expect(http.calls('GET', _list).last.queryParameters['page'], 1);
      expect(find.text('Reward 1'), findsOneWidget); // the first page stays
      expect(find.text('Reward 2'), findsOneWidget);
      expect(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore), findsNothing);
    });
  });

  group('applying a code', () {
    testWidgets('both fields are required', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.tap(_apply);
      await tester.pumpAndSettle();
      expect(find.text(en.loyaltyRedemptionApplyDialogTitle), findsOneWidget);

      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionApplyButton)));
      await tester.pumpAndSettle();
      expect(find.text(en.loyaltyRedemptionApplyValidationError), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionCodeLabel), 'CODE-1');
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionApplyButton)));
      await tester.pumpAndSettle();
      expect(find.text(en.loyaltyRedemptionApplyValidationError), findsOneWidget); // booking id still missing

      expect(http.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('a valid code is applied to the booking, the dialog closes and the list reloads', (tester) async {
      final http = _backend();
      http.reply('POST', '$_list/CODE-1/apply', _redemption('1', 'APPLIED', appliedBookingId: 'b-1'));
      await _open(tester, http);
      final loads = http.calls('GET', _list).length;

      await tester.tap(_apply);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionCodeLabel), '  CODE-1 ');
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionBookingIdLabel), ' b-1 ');
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionApplyButton)));
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', '$_list/CODE-1/apply'), {'bookingId': 'b-1'});
      expect(find.byType(Dialog), findsNothing);
      expect(http.calls('GET', _list).length, greaterThan(loads));
    });

    testWidgets('a rejected code shows the reason and keeps the dialog open', (tester) async {
      final http = _backend();
      http.fail('POST', '$_list/BAD/apply', 409, message: 'Code already used');
      await _open(tester, http);

      await tester.tap(_apply);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionCodeLabel), 'BAD');
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionBookingIdLabel), 'b-1');
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionApplyButton)));
      await tester.pumpAndSettle();

      expect(find.text('Code already used'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
    });

    Future<void> submit(WidgetTester tester, FakeHttp http, String code) async {
      await _open(tester, http);
      await tester.tap(_apply);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionCodeLabel), code);
      await tester.enterText(find.widgetWithText(TextField, en.loyaltyRedemptionBookingIdLabel), 'b-1');
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionApplyButton)));
      await tester.pumpAndSettle();
    }

    testWidgets('an unknown code (404) says it was not found', (tester) async {
      final http = _backend();
      http.fail('POST', '$_list/NOPE/apply', 404);
      await submit(tester, http, 'NOPE');

      expect(find.text(en.errorLoyaltyNotFound), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('a reply that cannot be understood shows the generic message and re-enables the form', (tester) async {
      final http = _backend();
      http.reply('POST', '$_list/ODD/apply', 'not an object');
      await submit(tester, http, 'ODD');

      expect(find.text(en.errorLoyaltyActionFailed), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, en.loyaltyRedemptionCodeLabel)).enabled, isTrue);
    });

    testWidgets('the dialog can be dismissed without sending anything', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.tap(_apply);
      await tester.pumpAndSettle();
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.cancelButton)));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(http.requests.where((r) => r.method == 'POST'), isEmpty);
    });
  });

  group('cancelling a redemption', () {
    Future<void> openCancel(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyRedemptionCancelButton));
      await tester.pumpAndSettle();
    }

    testWidgets('keeping it sends nothing', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await openCancel(tester);
      expect(find.text(en.loyaltyRedemptionCancelConfirmTitle), findsOneWidget);
      await tester.tap(_inDialog(find.text(en.cancelButton)));
      await tester.pumpAndSettle();

      expect(http.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('confirming with a reason sends the trimmed reason and reloads the list', (tester) async {
      final http = _backend();
      http.reply('POST', '$_list/1/cancel', _redemption('1', 'CANCELLED'));
      await _open(tester, http);
      final loads = http.calls('GET', _list).length;

      await openCancel(tester);
      await tester.enterText(find.byType(TextField), '  Customer changed plans ');
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionCancelButton)));
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', '$_list/1/cancel'), {'reason': 'Customer changed plans'});
      expect(http.calls('GET', _list).length, greaterThan(loads));
    });

    testWidgets('confirming without a reason sends no reason', (tester) async {
      final http = _backend();
      http.reply('POST', '$_list/1/cancel', _redemption('1', 'CANCELLED'));
      await _open(tester, http);

      await openCancel(tester);
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionCancelButton)));
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', '$_list/1/cancel'), {'reason': null});
    });

    testWidgets('a failure is reported in a snackbar', (tester) async {
      final http = _backend();
      http.fail('POST', '$_list/1/cancel', 403);
      await _open(tester, http);

      await openCancel(tester);
      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.loyaltyRedemptionCancelButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorLoyaltyForbidden), findsOneWidget);
    });
  });
}

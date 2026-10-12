import 'package:business_admin/features/loyalty/presentation/screens/loyalty_customer_detail_screen.dart';
import 'package:business_admin/features/loyalty/presentation/screens/loyalty_customers_screen.dart';
import 'package:business_admin/features/loyalty/presentation/widgets/loyalty_retention_badge.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _list = '/business/p1/loyalty/customers';
const _adjust = '/business/p1/loyalty/customers/u1/adjust';

Map<String, Object?> _customer(
  String id, {
  String? name,
  String? email,
  int balance = 450,
  String? retention = 'ACTIVE',
  String? lastActivity = '2026-10-10T10:00:00Z',
  int expiring = 0,
}) =>
    {
      'userId': id,
      'displayName': name,
      'email': email,
      'pointsBalance': balance,
      'lifetimeEarned': 900,
      'lifetimeRedeemed': 450,
      'completedVisits': 9,
      'lastActivityAt': lastActivity,
      'pointsExpiringSoon30d': expiring,
      'retentionStatus': retention,
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

FakeHttp _backend({List<Map<String, Object?>>? customers}) {
  final http = FakeHttp();
  http.reply('GET', _list, _page(customers ??
      [_customer('u1', name: 'Aigerim', email: 'aigerim@example.com'), _customer('u2', name: 'Dana', email: 'dana@example.com', retention: 'AT_RISK')]));
  return http;
}

Future<void> _openList(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const Scaffold(body: LoyaltyCustomersScreen(providerId: 'p1'))));
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const LoyaltyCustomerDetailScreen(providerId: 'p1', userId: 'u1')));
  await tester.pumpAndSettle();
}

void main() {
  group('roster', () {
    testWidgets('lists each member with balance, last activity and retention status', (tester) async {
      await _openList(tester, _backend());

      expect(find.text('Aigerim'), findsOneWidget);
      expect(find.text('Dana'), findsOneWidget);
      expect(find.text(en.loyaltyCustomerBalanceLabel(450)), findsNWidgets(2));
      expect(find.textContaining(en.loyaltyCustomerLastActivityLabel('').trim()), findsNWidgets(2));
      expect(find.text(en.loyaltyRetentionActive), findsOneWidget);
      expect(find.text(en.loyaltyRetentionAtRisk), findsOneWidget);
    });

    testWidgets('a member without a name shows the email, and without either a dash', (tester) async {
      await _openList(tester, _backend(customers: [
        _customer('u1', email: 'only@example.com', lastActivity: null),
        _customer('u2', retention: null),
      ]));

      expect(find.text('only@example.com'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(LoyaltyRetentionBadge), findsNWidgets(1 + 1));
      expect(find.textContaining(en.loyaltyCustomerLastActivityLabel('').trim()), findsOneWidget); // only u2 has activity
    });

    testWidgets('an empty programme says there are no members yet', (tester) async {
      await _openList(tester, _backend(customers: []));

      expect(find.text(en.loyaltyCustomersEmpty), findsOneWidget);
    });

    testWidgets('a roster that fails to load shows an error and retrying loads it', (tester) async {
      final http = _backend();
      http.fail('GET', _list, 500);
      await _openList(tester, http);
      expect(find.text(en.errorLoyaltyCustomersLoadFailed), findsOneWidget);

      http.reply('GET', _list, _page([_customer('u1', name: 'Aigerim')]));
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text('Aigerim'), findsOneWidget);
    });

    testWidgets('search filters by name or email, ignoring case, and says when nothing matches', (tester) async {
      await _openList(tester, _backend());

      await tester.enterText(find.byType(TextField), 'DANA');
      await tester.pumpAndSettle();
      expect(find.text('Dana'), findsOneWidget);
      expect(find.text('Aigerim'), findsNothing);

      await tester.enterText(find.byType(TextField), 'aigerim@');
      await tester.pumpAndSettle();
      expect(find.text('Aigerim'), findsOneWidget);
      expect(find.text('Dana'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(en.loyaltyCustomersSearchEmpty), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Aigerim'), findsOneWidget);
      expect(find.text('Dana'), findsOneWidget);
    });

    testWidgets('a long roster loads more on request; searching hides the load-more button', (tester) async {
      final http = FakeHttp();
      http.reply('GET', _list, _page([_customer('u1', name: 'Aigerim')], totalPages: 2));
      await _openList(tester, http);
      expect(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Aig');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      http.reply('GET', _list, _page([_customer('u9', name: 'Saule')], number: 1, totalPages: 2));
      await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore));
      await tester.pumpAndSettle();

      expect(find.text('Aigerim'), findsOneWidget);
      expect(find.text('Saule'), findsOneWidget);
      expect(find.widgetWithText(FactoryButton, en.loyaltyCustomersLoadMore), findsNothing);
    });

    testWidgets('tapping a member opens their detail screen', (tester) async {
      final http = _backend();
      http.reply('GET', '$_list/u1', _customer('u1', name: 'Aigerim', email: 'aigerim@example.com'));
      await _openList(tester, http);

      await tester.tap(find.text('Aigerim'));
      await tester.pumpAndSettle();

      expect(find.byType(LoyaltyCustomerDetailScreen), findsOneWidget);
      expect(http.calls('GET', '$_list/u1'), hasLength(1));
    });
  });

  group('retention badge', () {
    Future<void> badge(WidgetTester tester, String? status) async {
      await tester.pumpWidget(appOn(FakeHttp(), Scaffold(body: LoyaltyRetentionBadge(status: status))));
    }

    testWidgets('each known status has its label', (tester) async {
      for (final (status, label) in [
        ('NEW', en.loyaltyRetentionNew),
        ('ACTIVE', en.loyaltyRetentionActive),
        ('AT_RISK', en.loyaltyRetentionAtRisk),
        ('DUE_FOR_REBOOKING', en.loyaltyRetentionDueForRebooking),
        ('LOST', en.loyaltyRetentionLost),
      ]) {
        await badge(tester, status);
        expect(find.text(label), findsOneWidget, reason: status);
      }
    });

    testWidgets('an unknown status is shown as-is and no status shows nothing', (tester) async {
      await badge(tester, 'SOMETHING_NEW');
      expect(find.text('SOMETHING_NEW'), findsOneWidget);

      await badge(tester, null);
      expect(find.byType(FactoryBadge), findsNothing);
    });

    testWidgets('statuses are styled by how much attention they need', (tester) async {
      FactoryBadgeVariant variantOf(WidgetTester t) => t.widget<FactoryBadge>(find.byType(FactoryBadge)).variant;
      final expected = {
        'NEW': FactoryBadgeVariant.verified,
        'ACTIVE': FactoryBadgeVariant.available,
        'AT_RISK': FactoryBadgeVariant.limited,
        'DUE_FOR_REBOOKING': FactoryBadgeVariant.limited,
        'LOST': FactoryBadgeVariant.error,
        'UNKNOWN': FactoryBadgeVariant.neutral,
      };
      for (final entry in expected.entries) {
        await badge(tester, entry.key);
        expect(variantOf(tester), entry.value, reason: entry.key);
      }
    });
  });

  group('detail', () {
    FakeHttp detail(Map<String, Object?> customer) {
      final http = FakeHttp();
      http.reply('GET', '$_list/u1', customer);
      return http;
    }

    testWidgets('shows the member, their numbers and the last activity', (tester) async {
      await _openDetail(tester, detail(_customer('u1', name: 'Aigerim', email: 'aigerim@example.com')));

      expect(find.text('Aigerim'), findsWidgets); // app bar + card
      expect(find.text('aigerim@example.com'), findsOneWidget);
      for (final entry in {
        en.loyaltyCustomerDetailBalance: '450',
        en.loyaltyCustomerDetailLifetimeEarned: '900',
        en.loyaltyCustomerDetailLifetimeRedeemed: '450',
        en.loyaltyCustomerDetailVisits: '9',
      }.entries) {
        final tile = find.ancestor(of: find.text(entry.key), matching: find.byType(FactoryStatTile));
        expect(find.descendant(of: tile, matching: find.text(entry.value)), findsOneWidget, reason: entry.key);
      }
      expect(find.text(en.loyaltyCustomerDetailExpiringSoon), findsNothing);
      expect(find.text(en.loyaltyCustomerActionNone), findsOneWidget); // nothing to recommend for an active member
    });

    testWidgets('a member with no name falls back to the email and then to the generic title', (tester) async {
      await _openDetail(tester, detail(_customer('u1', email: 'only@example.com', lastActivity: null)));
      expect(find.text('only@example.com'), findsOneWidget);
      expect(find.textContaining(en.loyaltyCustomerLastActivityLabel('').trim()), findsNothing);
    });

    testWidgets('points about to expire are flagged and recommended for action', (tester) async {
      await _openDetail(tester, detail(_customer('u1', name: 'Aigerim', expiring: 40)));

      expect(find.text(en.loyaltyCustomerDetailExpiringSoon), findsOneWidget);
      expect(find.text(en.loyaltyCustomerActionPointsExpiring(40)), findsOneWidget);
      expect(find.text(en.loyaltyCustomerActionNone), findsNothing);
    });

    testWidgets('the recommended action follows the retention status', (tester) async {
      for (final (status, message) in [
        ('AT_RISK', en.loyaltyCustomerActionAtRisk),
        ('DUE_FOR_REBOOKING', en.loyaltyCustomerActionDueForRebooking),
        ('LOST', en.loyaltyCustomerActionLost),
      ]) {
        await _openDetail(tester, detail(_customer('u1', name: 'Aigerim', retention: status)));
        expect(find.text(message), findsOneWidget, reason: status);
      }
    });

    testWidgets('a member that fails to load shows an error and retrying loads it', (tester) async {
      final http = detail(_customer('u1', name: 'Aigerim'));
      http.fail('GET', '$_list/u1', 500);
      await _openDetail(tester, http);
      expect(find.text(en.errorLoyaltyCustomersLoadFailed), findsOneWidget);

      http.reply('GET', '$_list/u1', _customer('u1', name: 'Aigerim'));
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorLoyaltyCustomersLoadFailed), findsNothing);
    });

    group('adjusting points', () {
      Future<FakeHttp> openDialog(WidgetTester tester) async {
        final http = detail(_customer('u1', name: 'Aigerim', balance: 450));
        http.reply('POST', _adjust, {
          'id': 'tx1',
          'type': 'ADJUSTMENT',
          'pointsDelta': 50,
          'balanceAfter': 500,
          'createdAt': '2026-10-12T10:00:00Z',
        });
        await _openDetail(tester, http);
        await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsButton));
        await tester.pumpAndSettle();
        return http;
      }

      Finder dialog(Finder f) => find.descendant(of: find.byType(Dialog), matching: f);
      final delta = find.widgetWithText(TextField, en.loyaltyAdjustPointsDeltaLabel);
      final reason = find.widgetWithText(TextField, en.loyaltyAdjustPointsReasonLabel);
      final next = dialog(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsContinueButton));

      testWidgets('shows the current balance and asks for an amount and a reason', (tester) async {
        await openDialog(tester);

        expect(dialog(find.text(en.loyaltyAdjustPointsDialogTitle)), findsOneWidget);
        expect(find.text(en.loyaltyAdjustPointsCurrentBalanceLabel(450)), findsOneWidget);
      });

      testWidgets('a missing or zero amount, or a missing reason, is rejected before confirming', (tester) async {
        await openDialog(tester);

        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text(en.loyaltyAdjustPointsDeltaError), findsOneWidget);

        await tester.enterText(delta, '0');
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text(en.loyaltyAdjustPointsDeltaError), findsOneWidget);

        await tester.enterText(delta, '50');
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text(en.loyaltyAdjustPointsReasonError), findsOneWidget);
        expect(find.text(en.loyaltyAdjustPointsConfirmTitle), findsNothing);
      });

      testWidgets('a credit is confirmed with the projected balance, then sent and the page reloads', (tester) async {
        final http = await openDialog(tester);
        final loads = http.calls('GET', '$_list/u1').length;

        await tester.enterText(delta, ' 50 ');
        await tester.enterText(reason, ' Goodwill ');
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text(en.loyaltyAdjustPointsConfirmTitle), findsOneWidget);
        expect(find.text(en.loyaltyAdjustPointsConfirmCredit(50)), findsOneWidget);
        expect(find.text(en.loyaltyAdjustPointsConfirmProjectedBalance(500)), findsOneWidget);
        expect(find.text('${en.loyaltyAdjustPointsReasonLabel}: Goodwill'), findsOneWidget);

        await tester.tap(dialog(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsConfirmButton)));
        await tester.pumpAndSettle();

        expect(http.bodyOf('POST', _adjust), {'delta': 50, 'reason': 'Goodwill'});
        expect(find.byType(Dialog), findsNothing);
        expect(find.text(en.loyaltyAdjustPointsSuccessMessage), findsOneWidget);
        expect(http.calls('GET', '$_list/u1').length, greaterThan(loads));
      });

      testWidgets('a debit is confirmed as a deduction', (tester) async {
        await openDialog(tester);

        await tester.enterText(delta, '-100');
        await tester.enterText(reason, 'Mistake');
        await tester.tap(next);
        await tester.pumpAndSettle();

        expect(find.text(en.loyaltyAdjustPointsConfirmDebit(100)), findsOneWidget);
        expect(find.text(en.loyaltyAdjustPointsConfirmProjectedBalance(350)), findsOneWidget);
      });

      testWidgets('back returns to the form with what was typed', (tester) async {
        await openDialog(tester);
        await tester.enterText(delta, '25');
        await tester.enterText(reason, 'Because');
        await tester.tap(next);
        await tester.pumpAndSettle();

        await tester.tap(dialog(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsBackButton)));
        await tester.pumpAndSettle();

        expect(dialog(find.text(en.loyaltyAdjustPointsDialogTitle)), findsOneWidget);
        expect(tester.widget<TextField>(delta).controller!.text, '25');
      });

      testWidgets('cancel closes the dialog without sending anything', (tester) async {
        final http = await openDialog(tester);

        await tester.tap(dialog(find.widgetWithText(FactoryButton, en.cancelButton)));
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
        expect(find.text(en.loyaltyAdjustPointsSuccessMessage), findsNothing);
        expect(http.calls('POST', _adjust), isEmpty);
      });

      testWidgets('a server rejection is shown on the confirmation and can be retried', (tester) async {
        final http = await openDialog(tester);
        http.fail('POST', _adjust, 400, message: 'Balance cannot go negative');
        await tester.enterText(delta, '-9999');
        await tester.enterText(reason, 'Oops');
        await tester.tap(next);
        await tester.pumpAndSettle();

        await tester.tap(dialog(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsConfirmButton)));
        await tester.pumpAndSettle();

        expect(find.text('Balance cannot go negative'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsConfirmButton), findsOneWidget);
      });

      testWidgets('an unreadable reply shows the generic message', (tester) async {
        final http = await openDialog(tester);
        http.reply('POST', _adjust, 'not an object');
        await tester.enterText(delta, '10');
        await tester.enterText(reason, 'Fine');
        await tester.tap(next);
        await tester.pumpAndSettle();

        await tester.tap(dialog(find.widgetWithText(FactoryButton, en.loyaltyAdjustPointsConfirmButton)));
        await tester.pumpAndSettle();

        expect(find.text(en.errorLoyaltyActionFailed), findsOneWidget);
      });
    });
  });
}

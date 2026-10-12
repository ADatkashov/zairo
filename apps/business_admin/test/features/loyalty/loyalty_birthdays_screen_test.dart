import 'package:business_admin/features/loyalty/presentation/screens/loyalty_birthdays_screen.dart';
import 'package:business_admin/features/loyalty/presentation/widgets/loyalty_greeting_dialog.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _list = '/business/p1/loyalty/birthdays';
const _greet = '/business/p1/loyalty/customers/u1/greet';

Map<String, Object?> _birthday(
  String id, {
  String? name,
  int month = 10,
  int day = 20,
  int daysUntil = 8,
  int bonus = 30,
  bool awarded = false,
  bool greeted = false,
}) =>
    {
      'userId': id,
      'displayName': name,
      'month': month,
      'day': day,
      'daysUntil': daysUntil,
      'bonusPoints': bonus,
      'bonusAwarded': awarded,
      'greetedToday': greeted,
    };

FakeHttp _backend([List<Map<String, Object?>>? birthdays]) {
  final http = FakeHttp();
  http.reply('GET', _list, birthdays ?? [_birthday('u1', name: 'Aigerim')]);
  http.reply('POST', _greet, <String, Object?>{});
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const Scaffold(body: LoyaltyBirthdaysScreen(providerId: 'p1'))));
  await tester.pumpAndSettle();
}

Finder _inDialog(Finder f) => find.descendant(of: find.byType(Dialog), matching: f);

void main() {
  group('list', () {
    testWidgets('asks for the next 30 days and explains the window', (tester) async {
      final http = _backend();
      await _open(tester, http);

      expect(http.calls('GET', _list).single.queryParameters, {'days': 30});
      expect(find.text(en.loyaltyBirthdaysIntro(30)), findsOneWidget);
    });

    testWidgets('shows a member, their date and how far away it is', (tester) async {
      await _open(tester, _backend());

      expect(find.text('Aigerim'), findsOneWidget);
      expect(find.textContaining('October 20'), findsOneWidget);
      expect(find.textContaining(en.loyaltyBirthdaysInDays(8)), findsOneWidget);
    });

    testWidgets('today and tomorrow are named, not counted', (tester) async {
      await _open(tester, _backend([
        _birthday('u1', name: 'Alpha', daysUntil: 0),
        _birthday('u2', name: 'Beta', daysUntil: 1),
      ]));

      expect(find.textContaining(en.loyaltyBirthdaysToday), findsOneWidget);
      expect(find.textContaining(en.loyaltyBirthdaysTomorrow), findsOneWidget);
      expect(find.textContaining(en.loyaltyBirthdaysInDays(0)), findsNothing);
    });

    testWidgets('a 29 February birthday can be shown', (tester) async {
      await _open(tester, _backend([_birthday('u1', name: 'Leap', month: 2, day: 29, daysUntil: 100)]));

      expect(find.textContaining('February 29'), findsOneWidget);
    });

    testWidgets('a member without a name shows a dash', (tester) async {
      await _open(tester, _backend([_birthday('u1')]));

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('the birthday bonus is shown as pending, granted, or not at all when there is none', (tester) async {
      await _open(tester, _backend([
        _birthday('u1', name: 'Pending', bonus: 30),
        _birthday('u2', name: 'Granted', bonus: 50, awarded: true),
        _birthday('u3', name: 'None', bonus: 0),
      ]));

      expect(find.text(en.loyaltyBirthdaysBonusPending(30)), findsOneWidget);
      expect(find.text(en.loyaltyBirthdaysBonusAwarded(50)), findsOneWidget);
      expect(find.textContaining('pts'), findsNWidgets(2));
    });

    testWidgets('a member already greeted today shows that instead of a greet button', (tester) async {
      await _open(tester, _backend([
        _birthday('u1', name: 'Done', greeted: true),
        _birthday('u2', name: 'Open'),
      ]));

      expect(find.text(en.loyaltyGreetingAlreadySent), findsOneWidget);
      expect(find.text(en.loyaltyGreetingButton), findsOneWidget);
    });

    testWidgets('nobody with a birthday soon says so', (tester) async {
      await _open(tester, _backend([]));

      expect(find.text(en.loyaltyBirthdaysEmpty), findsOneWidget);
    });

    testWidgets('a list that fails to load shows an error and retrying loads it', (tester) async {
      final http = _backend();
      http.fail('GET', _list, 500);
      await _open(tester, http);
      expect(find.text(en.errorLoyaltyBirthdaysLoadFailed), findsOneWidget);

      http.reply('GET', _list, [_birthday('u1', name: 'Aigerim')]);
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text('Aigerim'), findsOneWidget);
    });
  });

  group('greeting a member', () {
    Future<FakeHttp> openGreeting(WidgetTester tester) async {
      final http = _backend();
      await _open(tester, http);
      await tester.tap(find.text(en.loyaltyGreetingButton));
      await tester.pumpAndSettle();
      return http;
    }

    Finder message() => find.widgetWithText(TextField, en.loyaltyGreetingMessageLabel);
    Finder points() => find.widgetWithText(TextField, en.loyaltyGreetingPointsLabel);
    Finder send() => _inDialog(find.widgetWithText(FactoryButton, en.loyaltyGreetingSendButton));

    testWidgets('the dialog names the member', (tester) async {
      await openGreeting(tester);

      expect(find.text(en.loyaltyGreetingDialogTitle('Aigerim')), findsOneWidget);
    });

    testWidgets('sending with nothing filled in sends no message and no points', (tester) async {
      final http = await openGreeting(tester);

      await tester.tap(send());
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', _greet), {'message': null, 'bonusPoints': null});
    });

    testWidgets('a message and gift points are sent trimmed; the dialog closes, confirms and reloads', (tester) async {
      final http = await openGreeting(tester);
      final loads = http.calls('GET', _list).length;

      await tester.enterText(message(), '  Happy birthday!  ');
      await tester.enterText(points(), ' 50 ');
      await tester.tap(send());
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', _greet), {'message': 'Happy birthday!', 'bonusPoints': 50});
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.loyaltyGreetingSent), findsOneWidget);
      expect(http.calls('GET', _list).length, greaterThan(loads));
    });

    testWidgets('zero gift points means no gift', (tester) async {
      final http = await openGreeting(tester);

      await tester.enterText(points(), '0');
      await tester.tap(send());
      await tester.pumpAndSettle();

      expect(http.bodyOf('POST', _greet)['bonusPoints'], isNull);
    });

    testWidgets('gift points must be a whole number from 0 up to the limit', (tester) async {
      final http = await openGreeting(tester);

      for (final bad in ['-1', 'lots', '1.5', '${loyaltyGreetingMaxPoints + 1}']) {
        await tester.enterText(points(), bad);
        await tester.tap(send());
        await tester.pumpAndSettle();
        expect(find.text(en.loyaltyGreetingPointsError(loyaltyGreetingMaxPoints)), findsOneWidget, reason: bad);
      }
      expect(http.calls('POST', _greet), isEmpty);

      await tester.enterText(points(), '$loyaltyGreetingMaxPoints');
      await tester.tap(send());
      await tester.pumpAndSettle();
      expect(http.bodyOf('POST', _greet)['bonusPoints'], loyaltyGreetingMaxPoints);
    });

    testWidgets('cancel closes the dialog without sending anything', (tester) async {
      final http = await openGreeting(tester);

      await tester.tap(_inDialog(find.widgetWithText(FactoryButton, en.cancelButton)));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(en.loyaltyGreetingSent), findsNothing);
      expect(http.calls('POST', _greet), isEmpty);
    });

    testWidgets('a server rejection is shown in the dialog, which stays open', (tester) async {
      final http = await openGreeting(tester);
      http.fail('POST', _greet, 409, message: 'Already greeted today');

      await tester.tap(send());
      await tester.pumpAndSettle();

      expect(find.text('Already greeted today'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(en.loyaltyGreetingSent), findsNothing);
    });

    testWidgets('a failure that is not an HTTP error shows the generic message', (tester) async {
      final http = await openGreeting(tester);
      http.fail('POST', _greet, 500);

      await tester.tap(send());
      await tester.pumpAndSettle();

      // A 500 carries no message, so the exception falls back to its own generic text.
      expect(find.text(en.errorLoyaltyActionFailed), findsOneWidget);
    });
  });
}

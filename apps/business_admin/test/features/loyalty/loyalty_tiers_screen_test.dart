import 'package:business_admin/features/loyalty/presentation/screens/loyalty_tiers_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _path = '/business/p1/loyalty/tiers';

Map<String, Object?> _tier(String id, String name, int min) => {'id': id, 'name': name, 'minLifetimePoints': min};

FakeHttp _backend([List<Map<String, Object?>>? tiers]) {
  final http = FakeHttp();
  http.reply('GET', _path, tiers ?? [_tier('t1', 'Silver', 500), _tier('t2', 'Gold', 1500)]);
  http.reply('PUT', _path, <Object?>[]);
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const Scaffold(body: LoyaltyTiersScreen(providerId: 'p1'))));
  await tester.pumpAndSettle();
}

Finder get _name => find.widgetWithText(TextField, en.loyaltyTierNameLabel);
Finder get _min => find.widgetWithText(TextField, en.loyaltyTierMinPointsLabel);
Finder get _save => find.widgetWithText(FactoryButton, en.saveButton);

Future<void> _saveForm(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Finder f, int i) => tester.widget<TextField>(f.at(i)).controller!.text;

void main() {
  testWidgets('shows each saved tier with its name and threshold', (tester) async {
    await _open(tester, _backend());

    expect(_name, findsNWidgets(2));
    expect([_text(tester, _name, 0), _text(tester, _min, 0)], ['Silver', '500']);
    expect([_text(tester, _name, 1), _text(tester, _min, 1)], ['Gold', '1500']);
  });

  testWidgets('with no tiers it says so', (tester) async {
    await _open(tester, _backend([]));

    expect(find.text(en.loyaltyTiersEmpty), findsOneWidget);
    expect(find.widgetWithText(FactoryButton, en.loyaltyTierAddButton), findsOneWidget);
    // Nothing to save yet: no Save button under an empty list.
    expect(find.widgetWithText(FactoryButton, en.saveButton), findsNothing);

    await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyTierAddButton));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FactoryButton, en.saveButton), findsOneWidget);
    expect(find.text(en.loyaltyTiersEmpty), findsNothing);
  });

  testWidgets('tiers that fail to load show an error and retrying loads them', (tester) async {
    final http = _backend();
    http.fail('GET', _path, 500);
    await _open(tester, http);
    expect(find.text(en.errorLoyaltyTiersLoadFailed), findsOneWidget);

    http.reply('GET', _path, [_tier('t1', 'Silver', 500)]);
    await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
    await tester.pumpAndSettle();

    expect(find.text(en.errorLoyaltyTiersLoadFailed), findsNothing);
    expect(_name, findsOneWidget);
  });

  testWidgets('add appends an empty row and remove drops the chosen one', (tester) async {
    await _open(tester, _backend());

    await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyTierAddButton));
    await tester.pumpAndSettle();
    expect(_name, findsNWidgets(3));

    await tester.tap(find.byTooltip(en.loyaltyTierRemoveButton).first);
    await tester.pumpAndSettle();
    expect(_name, findsNWidgets(2));
    expect(_text(tester, _name, 0), 'Gold');
  });

  testWidgets('saving sends the trimmed tiers and confirms', (tester) async {
    final http = _backend();
    await _open(tester, http);
    await tester.enterText(_name.at(0), '  Bronze ');
    await tester.enterText(_min.at(0), ' 0 ');

    await _saveForm(tester);

    expect(http.bodyOf('PUT', _path), {
      'tiers': [
        {'name': 'Bronze', 'minLifetimePoints': 0},
        {'name': 'Gold', 'minLifetimePoints': 1500},
      ],
    });
    expect(find.text(en.loyaltyTiersSavedMessage), findsOneWidget);
    expect(http.calls('GET', _path).length, greaterThan(1));
  });

  testWidgets('a threshold of zero is allowed but a negative or non-numeric one is not', (tester) async {
    final http = _backend([_tier('t1', 'Base', 100)]);
    await _open(tester, http);

    for (final bad in ['-1', 'many', '']) {
      await tester.enterText(_min.first, bad);
      await _saveForm(tester);
      expect(find.text(en.loyaltyTierValidationError), findsOneWidget, reason: '"$bad"');
    }
    expect(http.calls('PUT', _path), isEmpty);

    await tester.enterText(_min.first, '0');
    await _saveForm(tester);
    expect(http.calls('PUT', _path), hasLength(1));
  });

  testWidgets('a tier without a name cannot be saved', (tester) async {
    final http = _backend();
    await _open(tester, http);

    await tester.enterText(_name.first, '   ');
    await _saveForm(tester);

    expect(find.text(en.loyaltyTierValidationError), findsOneWidget);
    expect(http.calls('PUT', _path), isEmpty);
  });

  testWidgets('a server rejection is shown and the form stays editable', (tester) async {
    final http = _backend();
    http.fail('PUT', _path, 409, message: 'Thresholds must be unique');
    await _open(tester, http);

    await _saveForm(tester);

    expect(find.text('Thresholds must be unique'), findsOneWidget);
    expect(find.text(en.loyaltyTiersSavedMessage), findsNothing);
    expect(tester.widget<TextField>(_name.first).enabled, isTrue);
  });

  testWidgets('a reply that cannot be understood shows the generic message', (tester) async {
    final http = _backend();
    http.reply('PUT', _path, 'not a list');
    await _open(tester, http);

    await _saveForm(tester);

    expect(find.text(en.errorLoyaltyActionFailed), findsOneWidget);
  });
}

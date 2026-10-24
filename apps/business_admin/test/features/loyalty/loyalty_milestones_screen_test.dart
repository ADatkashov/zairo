import 'package:business_admin/features/loyalty/presentation/screens/loyalty_milestones_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _path = '/business/p1/loyalty/milestones';

Map<String, Object?> _milestone(String id, int visits, int points, {String? label}) =>
    {'id': id, 'visitsRequired': visits, 'pointsAwarded': points, 'label': label};

FakeHttp _backend([List<Map<String, Object?>>? milestones]) {
  final http = FakeHttp();
  http.reply('GET', _path, milestones ?? [_milestone('m1', 5, 100, label: 'Regular'), _milestone('m2', 10, 300)]);
  http.reply('PUT', _path, <Object?>[]);
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester);
  await tester.pumpWidget(appOn(http, const Scaffold(body: LoyaltyMilestonesScreen(providerId: 'p1'))));
  await tester.pumpAndSettle();
}

Finder get _visits => find.widgetWithText(TextField, en.loyaltyMilestoneVisitsLabel);
Finder get _points => find.widgetWithText(TextField, en.loyaltyMilestonePointsLabel);
Finder get _label => find.widgetWithText(TextField, '${en.loyaltyMilestoneLabelLabel} (${en.loyaltySettingsOptionalSuffix})');
Finder get _save => find.widgetWithText(FactoryButton, en.saveButton);

Future<void> _saveForm(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Finder f, int i) => tester.widget<TextField>(f.at(i)).controller!.text;

void main() {
  testWidgets('shows each saved milestone with its visits, points and label', (tester) async {
    await _open(tester, _backend());

    expect(_visits, findsNWidgets(2));
    expect([_text(tester, _visits, 0), _text(tester, _points, 0), _text(tester, _label, 0)], ['5', '100', 'Regular']);
    expect([_text(tester, _visits, 1), _text(tester, _points, 1), _text(tester, _label, 1)], ['10', '300', '']);
    expect(find.text(en.loyaltyMilestonesEmpty), findsNothing);
  });

  testWidgets('with no milestones it says so and offers to add one', (tester) async {
    await _open(tester, _backend([]));

    expect(find.text(en.loyaltyMilestonesEmpty), findsOneWidget);
    expect(find.widgetWithText(FactoryButton, en.loyaltyMilestoneAddButton), findsOneWidget);
    // Nothing to save yet: no Save button under an empty list.
    expect(_save, findsNothing);

    await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyMilestoneAddButton));
    await tester.pumpAndSettle();

    // A row now exists, so Save appears and the empty state is gone.
    expect(_visits, findsOneWidget);
    expect(_save, findsOneWidget);
    expect(find.text(en.loyaltyMilestonesEmpty), findsNothing);
  });

  testWidgets('a list that fails to load shows an error and retrying loads it', (tester) async {
    final http = _backend();
    http.fail('GET', _path, 500);
    await _open(tester, http);
    expect(find.text(en.errorLoyaltyMilestonesLoadFailed), findsOneWidget);

    http.reply('GET', _path, [_milestone('m1', 5, 100)]);
    await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
    await tester.pumpAndSettle();

    expect(find.text(en.errorLoyaltyMilestonesLoadFailed), findsNothing);
    expect(_visits, findsOneWidget);
  });

  testWidgets('add appends an empty row and remove drops the chosen one', (tester) async {
    await _open(tester, _backend());

    await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyMilestoneAddButton));
    await tester.pumpAndSettle();
    expect(_visits, findsNWidgets(3));
    expect(_text(tester, _visits, 2), isEmpty);

    await tester.tap(find.byTooltip(en.loyaltyMilestoneRemoveButton).first);
    await tester.pumpAndSettle();
    expect(_visits, findsNWidgets(2));
    expect(_text(tester, _visits, 0), '10'); // the first milestone is gone
  });

  testWidgets('saving sends the rows as typed, with blank labels as null, and confirms', (tester) async {
    final http = _backend();
    await _open(tester, http);
    await tester.enterText(_visits.at(1), ' 12 ');
    await tester.enterText(_label.at(0), '  VIP  ');

    await _saveForm(tester);

    expect(http.bodyOf('PUT', _path), {
      'milestones': [
        {'visitsRequired': 5, 'pointsAwarded': 100, 'label': 'VIP'},
        {'visitsRequired': 12, 'pointsAwarded': 300, 'label': null},
      ],
    });
    expect(find.text(en.loyaltyMilestonesSavedMessage), findsOneWidget);
    expect(http.calls('GET', _path).length, greaterThan(1)); // reloaded
  });

  testWidgets('removing every milestone saves an empty list', (tester) async {
    final http = _backend([_milestone('m1', 5, 100)]);
    await _open(tester, http);

    await tester.tap(find.byTooltip(en.loyaltyMilestoneRemoveButton));
    await tester.pumpAndSettle();
    await _saveForm(tester);

    expect(http.bodyOf('PUT', _path), {'milestones': <Object?>[]});
  });

  testWidgets('every row needs a positive visit count and a positive points value', (tester) async {
    final http = _backend();
    await _open(tester, http);

    for (final (visits, points) in [('0', '100'), ('abc', '100'), ('5', '0'), ('5', ''), ('-1', '100')]) {
      await tester.enterText(_visits.at(0), visits);
      await tester.enterText(_points.at(0), points);
      await _saveForm(tester);
      expect(find.text(en.loyaltyMilestoneValidationError), findsOneWidget, reason: '$visits / $points');
    }
    expect(http.calls('PUT', _path), isEmpty);
  });

  testWidgets('a new empty row blocks saving until it is filled in', (tester) async {
    final http = _backend();
    await _open(tester, http);

    await tester.tap(find.widgetWithText(FactoryButton, en.loyaltyMilestoneAddButton));
    await tester.pumpAndSettle();
    await _saveForm(tester);
    expect(find.text(en.loyaltyMilestoneValidationError), findsOneWidget);
    expect(http.calls('PUT', _path), isEmpty);

    await tester.enterText(_visits.at(2), '20');
    await tester.enterText(_points.at(2), '500');
    await _saveForm(tester);
    expect(find.text(en.loyaltyMilestoneValidationError), findsNothing);
    expect(http.calls('PUT', _path), hasLength(1));
  });

  testWidgets('a server rejection is shown and the form stays editable', (tester) async {
    final http = _backend();
    http.fail('PUT', _path, 400, message: 'Visit counts must be unique');
    await _open(tester, http);

    await _saveForm(tester);

    expect(find.text('Visit counts must be unique'), findsOneWidget);
    expect(find.text(en.loyaltyMilestonesSavedMessage), findsNothing);
    expect(tester.widget<TextField>(_visits.first).enabled, isTrue);
  });

  testWidgets('a reply that cannot be understood shows the generic message', (tester) async {
    final http = _backend();
    http.reply('PUT', _path, 'not a list');
    await _open(tester, http);

    await _saveForm(tester);

    expect(find.text(en.errorLoyaltyActionFailed), findsOneWidget);
  });
}

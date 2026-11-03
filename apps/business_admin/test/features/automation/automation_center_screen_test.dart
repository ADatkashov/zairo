import 'package:business_admin/features/automation/presentation/screens/automation_center_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/pump_app.dart';

const _settings = {
  'rebookEnabled': true,
  'reactivationEnabled': false,
  'smartFillEnabled': true,
  'rebookMinVisitsToEstablishInterval': 3,
  'rebookMinIntervalDays': 7,
  'rebookMaxIntervalDays': 60,
  'rebookFollowUpWindowDays': 5,
  'reactivationScanMinInactivityDays': 45,
  'reactivationIntervalMultiplier': 2.5,
  'reactivationAbsoluteMaxInactivityDays': 180,
  'reactivationFollowUpWindowDays': 10,
  'allowedHoursStart': 9,
  'allowedHoursEnd': 21,
  'timezone': 'Asia/Almaty',
  'cooldownDaysBetweenOffers': 14,
};

const _bare = {'rebookEnabled': false, 'reactivationEnabled': false, 'smartFillEnabled': false};

Map<String, Object?> _provider(String id, String name) =>
    {'id': id, 'ownerUserId': 'o1', 'name': name, 'vertical': 'beauty', 'status': 'ACTIVE'};

FakeHttp _backend({
  List<Map<String, Object?>>? providers,
  Map<String, Object?> settings = _settings,
}) {
  final http = FakeHttp();
  http.reply('GET', '/users/o1/providers', providers ?? [_provider('p1', 'Glow Salon')]);
  http.reply('GET', '/business/p1/automation/settings', settings);
  http.reply('GET', '/business/p2/automation/settings', {..._settings, 'smartFillEnabled': false});
  http.reply('PUT', '/business/p1/automation/settings', settings);
  return http;
}

Future<void> _open(WidgetTester tester, FakeHttp http) async {
  useTallScreen(tester, size: const Size(800, 4000));
  await tester.pumpWidget(appOn(http, const AutomationCenterScreen(ownerUserId: 'o1')));
  await tester.pumpAndSettle();
  // The numeric fields sit under "Advanced settings" (collapsed); open it when there is one.
  final advanced = find.text(en.automationAdvancedTitle);
  if (advanced.evaluate().isNotEmpty) {
    await tester.tap(advanced);
    await tester.pumpAndSettle();
  }
}

Finder _field(String label) => find.widgetWithText(TextField, '$label (${en.loyaltySettingsOptionalSuffix})');
Finder get _save => find.widgetWithText(FactoryButton, en.saveButton);

Future<void> _saveForm(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _sent(FakeHttp http) => http.calls('PUT', '/business/p1/automation/settings').last.data as Map<String, dynamic>;

void main() {
  group('before the form', () {
    testWidgets('someone with no business is told to add one', (tester) async {
      await _open(tester, _backend(providers: []));

      expect(find.text(en.automationCenterNoBusinesses), findsOneWidget);
      expect(_save, findsNothing);
    });

    testWidgets('businesses that fail to load show an error and retrying works', (tester) async {
      final http = _backend();
      http.fail('GET', '/users/o1/providers', 500);
      await _open(tester, http);
      expect(find.text(en.errorBusinessesLoadFailed), findsOneWidget);

      http.reply('GET', '/users/o1/providers', [_provider('p1', 'Glow Salon')]);
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorBusinessesLoadFailed), findsNothing);
      expect(_save, findsOneWidget);
    });

    testWidgets('settings that fail to load show an error and retrying works', (tester) async {
      final http = _backend();
      http.fail('GET', '/business/p1/automation/settings', 500);
      await _open(tester, http);
      expect(find.text(en.errorAutomationSettingsLoadFailed), findsOneWidget);
      expect(_save, findsNothing);

      http.reply('GET', '/business/p1/automation/settings', _settings);
      await tester.tap(find.descendant(of: find.byType(FactoryErrorState), matching: find.byType(FactoryButton)));
      await tester.pumpAndSettle();

      expect(find.text(en.errorAutomationSettingsLoadFailed), findsNothing);
      expect(_save, findsOneWidget);
    });

    testWidgets('one business shows no picker', (tester) async {
      await _open(tester, _backend());

      expect(find.byType(FactoryChip), findsNothing);
    });

    testWidgets('several businesses show a chip each; picking another loads that business', (tester) async {
      final http = _backend(providers: [_provider('p1', 'Glow Salon'), _provider('p2', 'Auto Pro')]);
      await _open(tester, http);
      expect(find.byType(FactoryChip), findsNWidgets(2));
      expect(http.calls('GET', '/business/p2/automation/settings'), isEmpty);

      await tester.tap(find.text('Glow Salon')); // already selected: nothing new to load
      await tester.pumpAndSettle();
      expect(http.calls('GET', '/business/p1/automation/settings'), hasLength(1));

      await tester.tap(find.text('Auto Pro'));
      await tester.pumpAndSettle();
      expect(http.calls('GET', '/business/p2/automation/settings'), hasLength(1));
    });
  });

  group('the form', () {
    testWidgets('shows the saved values in every field and switch', (tester) async {
      await _open(tester, _backend());

      String text(String label, {int at = 0}) =>
          tester.widget<TextField>(_field(label).at(at)).controller!.text;
      expect(text(en.automationRebookMinVisitsLabel), '3');
      expect(text(en.automationRebookMinIntervalLabel), '7');
      expect(text(en.automationRebookMaxIntervalLabel), '60');
      expect(text(en.automationRebookFollowUpLabel), '5'); // same label twice: rebook is first
      expect(text(en.automationReactivationScanMinLabel), '45');
      expect(text(en.automationReactivationMultiplierLabel), '2.5');
      expect(text(en.automationReactivationAbsoluteMaxLabel), '180');
      expect(text(en.automationReactivationFollowUpLabel, at: 1), '10');
      expect(text(en.automationAllowedHoursStartLabel), '9');
      expect(text(en.automationAllowedHoursEndLabel), '21');
      expect(text(en.automationCooldownLabel), '14');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, en.automationTimezoneLabel)).controller!.text,
          'Asia/Almaty');

      bool on(String title) => tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title)).value;
      expect(on(en.automationSmartFillEnableTitle), isTrue);
      expect(on(en.automationRebookEnableTitle), isTrue);
      expect(on(en.automationReactivationEnableTitle), isFalse);
    });

    testWidgets('a pace is one tap: it fills the numbers, the hint changes, and saving sends them', (tester) async {
      final http = _backend(settings: {..._settings, 'rebookMinVisitsToEstablishInterval': null, 'rebookMinIntervalDays': null,
        'rebookMaxIntervalDays': null, 'rebookFollowUpWindowDays': null, 'reactivationScanMinInactivityDays': null,
        'reactivationIntervalMultiplier': null, 'reactivationAbsoluteMaxInactivityDays': null,
        'reactivationFollowUpWindowDays': null, 'allowedHoursStart': null, 'allowedHoursEnd': null, 'cooldownDaysBetweenOffers': null});
      await _open(tester, http);
      // All empty = the platform defaults = "Standard".
      expect(find.text(en.automationPresetStandardHint), findsOneWidget);

      await tester.tap(find.text(en.automationPresetCareful));
      await tester.pumpAndSettle();
      expect(find.text(en.automationPresetCarefulHint), findsOneWidget);
      expect(tester.widget<TextField>(_field(en.automationCooldownLabel)).controller!.text, '14');

      await _saveForm(tester);
      expect(_sent(http)['cooldownDaysBetweenOffers'], 14);
      expect(_sent(http)['rebookMinVisitsToEstablishInterval'], 3);
      expect(_sent(http)['allowedHoursStart'], 10);

      await tester.tap(find.text(en.automationPresetStandard));
      await tester.pumpAndSettle();
      await _saveForm(tester);
      expect(_sent(http)['cooldownDaysBetweenOffers'], isNull);
      expect(_sent(http)['allowedHoursStart'], isNull);
    });

    testWidgets('editing a number by hand leaves no pace highlighted and says so', (tester) async {
      final http = _backend(settings: {..._settings, 'rebookMinVisitsToEstablishInterval': null, 'rebookMinIntervalDays': null,
        'rebookMaxIntervalDays': null, 'rebookFollowUpWindowDays': null, 'reactivationScanMinInactivityDays': null,
        'reactivationIntervalMultiplier': null, 'reactivationAbsoluteMaxInactivityDays': null,
        'reactivationFollowUpWindowDays': null, 'allowedHoursStart': null, 'allowedHoursEnd': null, 'cooldownDaysBetweenOffers': null});
      await _open(tester, http);

      await tester.enterText(_field(en.automationCooldownLabel), '9');
      await tester.pumpAndSettle();

      expect(find.text(en.automationPresetCustomHint), findsOneWidget);
      expect(find.text(en.automationPresetStandardHint), findsNothing);
    });

    testWidgets('empty settings leave every field blank', (tester) async {
      await _open(tester, _backend(settings: _bare));

      expect(tester.widget<TextField>(_field(en.automationRebookMinVisitsLabel)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(_field(en.automationCooldownLabel)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, en.automationTimezoneLabel)).controller!.text,
          isEmpty);
    });

    testWidgets('saving sends every value as edited and confirms', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.tap(find.widgetWithText(SwitchListTile, en.automationReactivationEnableTitle));
      await tester.tap(find.widgetWithText(SwitchListTile, en.automationSmartFillEnableTitle));
      await tester.tap(find.widgetWithText(SwitchListTile, en.automationRebookEnableTitle));
      await tester.enterText(_field(en.automationRebookMinVisitsLabel), ' 4 ');
      await tester.enterText(_field(en.automationReactivationMultiplierLabel), '3.25');
      await tester.enterText(_field(en.automationCooldownLabel), '30');
      await tester.enterText(find.widgetWithText(TextField, en.automationTimezoneLabel), '  Europe/Berlin  ');
      await _saveForm(tester);

      final body = _sent(http);
      expect(body['reactivationEnabled'], isTrue);
      expect(body['smartFillEnabled'], isFalse);
      expect(body['rebookEnabled'], isFalse);
      expect(body['rebookMinVisitsToEstablishInterval'], 4);
      expect(body['reactivationIntervalMultiplier'], 3.25);
      expect(body['cooldownDaysBetweenOffers'], 30);
      expect(body['timezone'], 'Europe/Berlin');
      expect(body['allowedHoursStart'], 9); // untouched fields are sent back as they were
      expect(body['rebookMaxIntervalDays'], 60);
      expect(find.text(en.automationSettingsSavedMessage), findsOneWidget);
      expect(http.calls('GET', '/business/p1/automation/settings').length, greaterThan(1)); // reloaded
    });

    testWidgets('blank optional fields are sent as null, not as zero or empty text', (tester) async {
      final http = _backend();
      await _open(tester, http);

      for (final label in [
        en.automationRebookMinVisitsLabel,
        en.automationRebookMinIntervalLabel,
        en.automationReactivationMultiplierLabel,
        en.automationCooldownLabel,
        en.automationAllowedHoursStartLabel,
        en.automationAllowedHoursEndLabel,
      ]) {
        await tester.enterText(_field(label), '');
      }
      await tester.enterText(find.widgetWithText(TextField, en.automationTimezoneLabel), '   ');
      await _saveForm(tester);

      final body = _sent(http);
      for (final key in [
        'rebookMinVisitsToEstablishInterval',
        'rebookMinIntervalDays',
        'reactivationIntervalMultiplier',
        'cooldownDaysBetweenOffers',
        'allowedHoursStart',
        'allowedHoursEnd',
        'timezone',
      ]) {
        expect(body[key], isNull, reason: key);
      }
      expect(body['rebookMaxIntervalDays'], 60);
    });

    testWidgets('text that is not a number is saved as blank', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.enterText(_field(en.automationCooldownLabel), 'soon');
      await _saveForm(tester);

      expect(_sent(http)['cooldownDaysBetweenOffers'], isNull);
    });

    testWidgets('allowed hours need both ends or neither', (tester) async {
      final http = _backend();
      await _open(tester, http);

      await tester.enterText(_field(en.automationAllowedHoursEndLabel), '');
      await _saveForm(tester);
      expect(find.text(en.automationAllowedHoursValidationError), findsOneWidget);
      expect(http.calls('PUT', '/business/p1/automation/settings'), isEmpty);

      await tester.enterText(_field(en.automationAllowedHoursStartLabel), '');
      await _saveForm(tester);
      expect(find.text(en.automationAllowedHoursValidationError), findsNothing);
      expect(http.calls('PUT', '/business/p1/automation/settings'), hasLength(1));
    });

    testWidgets('a server rejection is shown on the form, which stays usable', (tester) async {
      final http = _backend();
      http.fail('PUT', '/business/p1/automation/settings', 400, message: 'Hours must be 0-23');
      await _open(tester, http);

      await _saveForm(tester);

      expect(find.text('Hours must be 0-23'), findsOneWidget);
      expect(find.text(en.automationSettingsSavedMessage), findsNothing);
      expect(tester.widget<TextField>(_field(en.automationCooldownLabel)).enabled, isTrue);
    });

    testWidgets('being forbidden shows the localized access message', (tester) async {
      final http = _backend();
      http.fail('PUT', '/business/p1/automation/settings', 403);
      await _open(tester, http);

      await _saveForm(tester);

      expect(find.text(en.errorAutomationForbidden), findsOneWidget);
    });
  });
}

import 'package:business_admin/features/automation/data/api/automation_api.dart';
import 'package:business_admin/features/automation/data/automation_exception.dart';
import 'package:business_admin/features/automation/data/models/automation_settings.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _json = {
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

Future<AutomationException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on AutomationException catch (e) {
    return e;
  }
  fail('expected an AutomationException');
}

void main() {
  late FakeHttp http;
  late AutomationApi api;

  setUp(() {
    http = FakeHttp();
    api = AutomationApi(http.client());
  });

  test('fetchSettings parses all fifteen settings', () async {
    http.reply('GET', '/business/p1/automation/settings', _json);

    final s = await api.fetchSettings('p1');

    expect([s.rebookEnabled, s.reactivationEnabled, s.smartFillEnabled], [true, false, true]);
    expect([s.rebookMinVisitsToEstablishInterval, s.rebookMinIntervalDays, s.rebookMaxIntervalDays,
        s.rebookFollowUpWindowDays], [3, 7, 60, 5]);
    expect([s.reactivationScanMinInactivityDays, s.reactivationAbsoluteMaxInactivityDays,
        s.reactivationFollowUpWindowDays], [45, 180, 10]);
    expect(s.reactivationIntervalMultiplier, 2.5);
    expect([s.allowedHoursStart, s.allowedHoursEnd, s.timezone, s.cooldownDaysBetweenOffers],
        [9, 21, 'Asia/Almaty', 14]);
  });

  test('every tunable may be absent (the backend then uses its defaults)', () async {
    http.reply('GET', '/business/p1/automation/settings',
        {'rebookEnabled': false, 'reactivationEnabled': false, 'smartFillEnabled': false});

    final s = await api.fetchSettings('p1');

    expect(s.rebookMinIntervalDays, isNull);
    expect(s.reactivationIntervalMultiplier, isNull);
    expect(s.timezone, isNull);
    expect(s.cooldownDaysBetweenOffers, isNull);
  });

  test('updateSettings puts the same fifteen fields it reads and returns the saved settings', () async {
    http.reply('GET', '/business/p1/automation/settings', _json);
    http.reply('PUT', '/business/p1/automation/settings', {..._json, 'reactivationEnabled': true});
    final current = await api.fetchSettings('p1');

    final saved = await api.updateSettings('p1', current);

    expect(http.bodyOf('PUT', '/business/p1/automation/settings'), _json);
    expect(saved.reactivationEnabled, isTrue);
    expect(const AutomationSettings(rebookEnabled: false, reactivationEnabled: false, smartFillEnabled: false)
        .toUpdateJson()
        .length, 15);
  });

  test('HTTP errors become an AutomationException carrying the status and the server message', () async {
    http.fail('GET', '/business/p1/automation/settings', 400, message: 'Hours are invalid');
    final e = await _failure(() => api.fetchSettings('p1'));
    expect(e.statusCode, 400);
    expect(e.serverMessage, 'Hours are invalid');

    http.reply('PUT', '/business/p1/automation/settings', 'not json object', status: 500);
    final e2 = await _failure(() => api.updateSettings('p1',
        const AutomationSettings(rebookEnabled: false, reactivationEnabled: false, smartFillEnabled: false)));
    expect(e2.statusCode, 500);
    expect(e2.serverMessage, isNull);
  });

  test('localized messages: 400 and others use the server text when there is one, 403 never does', () {
    final l10n = AppLocalizationsEn();
    String message(int? status, {String? server}) =>
        AutomationException(statusCode: status, serverMessage: server).localizedMessage(l10n);

    expect(message(400, server: 'Hours are invalid'), 'Hours are invalid');
    expect(message(400), l10n.errorAutomationValidationFailed);
    expect(message(403, server: 'raw'), l10n.errorAutomationForbidden);
    expect(message(500, server: 'Database down'), 'Database down');
    expect(message(500), l10n.errorAutomationActionFailed);
    expect(message(null), l10n.errorAutomationActionFailed);
    expect(const AutomationException(statusCode: 403).toString(), contains('403'));
  });
}

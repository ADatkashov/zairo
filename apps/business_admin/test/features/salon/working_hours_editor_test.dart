import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/features/salon/presentation/widgets/working_hours_editor.dart';
import 'package:business_admin/l10n/app_localizations.dart';

Widget _app(
  Map<String, String> hours,
  ValueChanged<Map<String, String>> onChanged,
) => MaterialApp(
  theme: factoryLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: SingleChildScrollView(
      child: WorkingHoursEditor(hours: hours, onChanged: onChanged),
    ),
  ),
);

void main() {
  test('workingHoursValid', () {
    expect(workingHoursValid(const {}), isTrue);
    expect(workingHoursValid(const {'mon': '09:00-20:00'}), isTrue);
    expect(workingHoursValid(const {'mon': '20:00-09:00'}), isFalse);
    expect(workingHoursValid(const {'mon': '09:00-09:00'}), isFalse);
    expect(workingHoursValid(const {'mon': 'x'}), isFalse);
  });

  testWidgets('turning a day on gives it the default range, off removes it', (
    tester,
  ) async {
    Map<String, String>? changed;
    await tester.pumpWidget(_app(const {}, (h) => changed = h));
    expect(find.text('Day off'), findsNWidgets(7));
    await tester.tap(find.byType(Switch).first);
    expect(changed, {'mon': defaultWorkingRange});

    await tester.pumpWidget(
      _app(const {'mon': '09:00-20:00'}, (h) => changed = h),
    );
    await tester.tap(find.byType(Switch).first);
    expect(changed, isEmpty);
  });

  testWidgets('Monday can be applied to every day', (tester) async {
    Map<String, String>? changed;
    await tester.pumpWidget(
      _app(const {'mon': '08:00-17:00'}, (h) => changed = h),
    );
    await tester.tap(find.text('Apply Monday to all days'));
    expect(changed!.length, 7);
    expect(changed!.values.toSet(), {'08:00-17:00'});
  });

  testWidgets('no apply-to-all when Monday is a day off', (tester) async {
    await tester.pumpWidget(_app(const {'tue': '08:00-17:00'}, (_) {}));
    expect(find.text('Apply Monday to all days'), findsNothing);
  });

  testWidgets('picking an opening time rewrites only that bound', (
    tester,
  ) async {
    Map<String, String>? changed;
    await tester.pumpWidget(
      _app(const {'mon': '09:00-20:00'}, (h) => changed = h),
    );
    await tester.tap(find.byKey(const ValueKey('open-mon')));
    await tester.pumpAndSettle();
    // The dial picker's OK without moving the hands keeps 09:00; switch to text input and type 10:30.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changed, {'mon': '10:30-20:00'});
  });

  testWidgets('cancelling the time picker changes nothing', (tester) async {
    Map<String, String>? changed;
    await tester.pumpWidget(
      _app(const {'mon': '09:00-20:00'}, (h) => changed = h),
    );
    await tester.tap(find.byKey(const ValueKey('close-mon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changed, isNull);
  });

  testWidgets('picking a closing time rewrites only the end', (tester) async {
    Map<String, String>? changed;
    await tester.pumpWidget(
      _app(const {'mon': '09:00-20:00'}, (h) => changed = h),
    );
    await tester.tap(find.byKey(const ValueKey('close-mon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(changed, {'mon': '09:00-20:00'});
  });
}

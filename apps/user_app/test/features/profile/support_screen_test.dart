import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/profile/presentation/screens/support_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _app({Locale locale = const Locale('en'), double textScale = 1}) => MaterialApp(
  theme: factoryLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  builder: (context, child) =>
      MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
  home: const SupportScreen(),
);

void main() {
  testWidgets('questions are listed first and an answer opens on a tap', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Common questions'), findsOneWidget);
    expect(find.text('How do I book?'), findsOneWidget);
    expect(find.textContaining('pick a service'), findsNothing);

    await tester.tap(find.text('How do I book?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pick a service'), findsOneWidget);

    await tester.tap(find.text('How do I book?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pick a service'), findsNothing);
  });

  testWidgets('a person is still one scroll away: the Telegram contact follows the questions', (tester) async {
    await tester.pumpWidget(_app());
    await tester.scrollUntilVisible(find.text('@ADatkashov'), 200);
    expect(find.text('Didn’t find your answer?'), findsOneWidget);
    expect(find.text('@ADatkashov'), findsOneWidget);
  });

  for (final locale in const [Locale('ru'), Locale('kk')]) {
    testWidgets('fits a 320 px phone with a large font in ${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(locale: locale, textScale: 2));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('@ADatkashov'), 300);
      expect(tester.takeException(), isNull);
    });
  }
}

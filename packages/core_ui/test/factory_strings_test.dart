import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
      theme: factoryLightTheme(),
      home: Localizations(
        locale: locale,
        delegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Scaffold(body: child),
      ),
    );

void main() {
  test('every product language has every built-in label', () {
    for (final code in ['en', 'ru', 'kk']) {
      final s = FactoryStrings.forLanguage(code);
      for (final value in [
        s.retry,
        s.showPassword,
        s.hidePassword,
        s.filters,
        s.clear,
        s.addToFavorites,
        s.removeFromFavorites,
        s.priceFrom,
      ]) {
        expect(value.trim(), isNotEmpty, reason: code);
      }
    }
    expect(FactoryStrings.forLanguage('de').retry, 'Try again');
    expect(FactoryStrings.forLanguage('ru').retry, isNot('Try again'));
  });

  testWidgets('error state retry label follows the locale', (tester) async {
    await tester.pumpWidget(_host(
      const Locale('kk'),
      FactoryErrorState(message: 'x', onRetry: () {}),
    ));
    expect(find.text('Қайталау'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('an explicit retry label still wins', (tester) async {
    await tester.pumpWidget(_host(
      const Locale('ru'),
      FactoryErrorState(message: 'x', onRetry: () {}, retryLabel: 'Again'),
    ));
    expect(find.text('Again'), findsOneWidget);
  });
}

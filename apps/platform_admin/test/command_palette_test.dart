import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('Ctrl+K opens quick search; typing a name finds the business and opens its details', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(1400, 900));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Jump to a page or business…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zen Spa').last);
    await tester.pumpAndSettle();

    // The business card is open (its status badge and payouts section are there).
    expect(find.text('Technical IDs'), findsOneWidget);
  });

  testWidgets('quick search jumps to an area and says so when nothing matches', (tester) async {
    await pumpConsole(tester, backend: defaultBackend(), size: const Size(1400, 900));

    await tester.tap(find.text('Quick search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No results'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cities');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Almaty'), findsOneWidget);
  });
}

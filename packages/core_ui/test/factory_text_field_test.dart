import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _height(WidgetTester tester, {int? minLines, required int maxLines}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: factoryLightTheme(),
      home: Scaffold(body: Center(child: SizedBox(width: 300, child: FactoryTextField(label: 'Message', minLines: minLines, maxLines: maxLines)))),
    ),
  );
  return tester.getSize(find.byType(TextFormField)).height;
}

void main() {
  testWidgets('a growing composer (minLines 1, maxLines 4) starts one line tall', (tester) async {
    final composer = await _height(tester, minLines: 1, maxLines: 4);
    final single = await _height(tester, maxLines: 1);
    final fixedFour = await _height(tester, maxLines: 4);
    expect(composer, single);
    expect(fixedFour, greaterThan(composer));
  });
}

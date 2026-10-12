import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/provider_grid.dart';

Future<SliverGridDelegateWithFixedCrossAxisCount> _delegate(WidgetTester tester, Size size, {double textScale = 1}) async {
  late SliverGridDelegate delegate;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (context) {
            delegate = providerGridDelegate(context, crossAxisCount: providerGridColumns(context), spacing: 12);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return delegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  testWidgets('a phone sizes provider cards by aspect ratio', (tester) async {
    final d = await _delegate(tester, const Size(390, 844));
    expect(d.crossAxisCount, 2);
    expect(d.mainAxisExtent, isNull);
    expect(d.childAspectRatio, 0.78);
  });

  testWidgets('a wide screen fixes the card height instead of stretching it', (tester) async {
    final tablet = await _delegate(tester, const Size(800, 600));
    final desktop = await _delegate(tester, const Size(1400, 900));
    expect(tablet.crossAxisCount, 3);
    expect(desktop.crossAxisCount, 4);
    expect(tablet.mainAxisExtent, 232);
    expect(desktop.mainAxisExtent, 232);
  });

  testWidgets('a "Book" button adds its height to the fixed card height on a wide screen', (tester) async {
    late SliverGridDelegateWithFixedCrossAxisCount plain;
    late SliverGridDelegateWithFixedCrossAxisCount withButton;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            plain = providerGridDelegate(context, crossAxisCount: 4, spacing: 12) as SliverGridDelegateWithFixedCrossAxisCount;
            withButton = providerGridDelegate(context, crossAxisCount: 4, spacing: 12, actionHeight: providerCardActionHeight)
                as SliverGridDelegateWithFixedCrossAxisCount;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(withButton.mainAxisExtent, plain.mainAxisExtent! + providerCardActionHeight);
  });

  testWidgets('the fixed height grows with the system font', (tester) async {
    final big = await _delegate(tester, const Size(1400, 900), textScale: 1.5);
    expect(big.mainAxisExtent, 128 + 104 * 1.5);
  });
}

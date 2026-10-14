import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, height: 176, child: child)),
  ),
);

void main() {
  // In flutter_test every Image.network fails (HTTP 400), which is exactly the
  // "cover failed to load" path: the card must still render its text.
  testWidgets('renders title and subtitle over the fallback when the cover cannot load', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryBannerCard(
          imageUrl: 'https://cdn.example/cover.jpg',
          title: 'AI & Digital Bridge',
          subtitle: 'Watch the highlights',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI & Digital Bridge'), findsOneWidget);
    expect(find.text('Watch the highlights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the tag and the play badge only when asked', (tester) async {
    await tester.pumpWidget(
      _wrap(const FactoryBannerCard(imageUrl: 'https://cdn.example/c.jpg', title: 'Plain')),
    );
    await tester.pump();
    expect(find.byIcon(Symbols.play_arrow_rounded), findsNothing);
    expect(find.text('Ad'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const FactoryBannerCard(
          imageUrl: 'https://cdn.example/c.jpg',
          title: 'Sponsored',
          tag: 'Ad',
          showPlay: true,
          playLabel: 'Watch video',
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
    expect(find.text('Ad'), findsOneWidget);
    expect(find.bySemanticsLabel('Sponsored, Watch video'), findsOneWidget);
  });

  testWidgets('a tap calls onTap and the label has no play hint without a video', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        FactoryBannerCard(
          imageUrl: 'https://cdn.example/c.jpg',
          title: 'Tap me',
          playLabel: 'Watch video',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tap me'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Tap me'), findsOneWidget);
  });
}

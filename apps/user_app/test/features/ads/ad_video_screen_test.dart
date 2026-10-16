import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/ads/presentation/screens/ad_video_screen.dart';

Widget _app(AdVideoScreen screen) => MaterialApp(theme: factoryLightTheme(), home: screen);

void main() {
  group('AdVideoScreen.isAllowed', () {
    test('only https links', () {
      expect(AdVideoScreen.isAllowed('https://video.example/v'), isTrue);
      expect(AdVideoScreen.isAllowed('http://video.example/v'), isFalse);
      expect(AdVideoScreen.isAllowed('javascript:alert(1)'), isFalse);
      expect(AdVideoScreen.isAllowed('file:///etc/passwd'), isFalse);
      expect(AdVideoScreen.isAllowed('intent://scan/#Intent;end'), isFalse);
      expect(AdVideoScreen.isAllowed('not a url'), isFalse);
      expect(AdVideoScreen.isAllowed(''), isFalse);
    });
  });

  testWidgets('shows the title and hands an https link to the player', (tester) async {
    String? played;
    await tester.pumpWidget(
      _app(
        AdVideoScreen(
          args: const AdVideoArgs(url: 'https://video.example/v', title: 'Highlights'),
          viewBuilder: (url) {
            played = url;
            return const Text('player');
          },
        ),
      ),
    );

    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('player'), findsOneWidget);
    expect(played, 'https://video.example/v');
  });

  testWidgets('never builds the player for a link that is not https', (tester) async {
    var built = false;
    await tester.pumpWidget(
      _app(
        AdVideoScreen(
          args: const AdVideoArgs(url: 'http://video.example/v', title: 'Highlights'),
          viewBuilder: (url) {
            built = true;
            return const Text('player');
          },
        ),
      ),
    );

    expect(built, isFalse);
    expect(find.byIcon(Symbols.link_off_rounded), findsOneWidget);
  });
}

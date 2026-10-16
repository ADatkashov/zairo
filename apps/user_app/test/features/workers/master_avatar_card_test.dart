import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/workers/presentation/widgets/master_avatar_card.dart';
import 'package:zairo/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  theme: factoryLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('shows the name and rating, and a tap fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        MasterAvatarCard(
          displayName: 'Aigerim K.',
          photoUrl: null,
          averageRating: 4.8,
          reviewCount: 17,
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.byType(FactoryRatingLabel), findsOneWidget);
    await tester.tap(find.text('Aigerim K.'));
    expect(taps, 1);
  });

  testWidgets('a master nobody reviewed yet has no rating row', (tester) async {
    await tester.pumpWidget(
      _app(
        MasterAvatarCard(displayName: 'New Master', photoUrl: null, averageRating: null, reviewCount: 0, onTap: () {}),
      ),
    );

    expect(find.text('New Master'), findsOneWidget);
    expect(find.byType(FactoryRatingLabel), findsNothing);
  });

  testWidgets('an optional caption sits under the rating and the card height makes room for it', (tester) async {
    await tester.pumpWidget(
      _app(
        MasterAvatarCard(
          displayName: 'Aigerim',
          photoUrl: null,
          averageRating: 4.8,
          reviewCount: 3,
          caption: 'Today 14:00',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Today 14:00'), findsOneWidget);
    late double plain;
    late double withCaption;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            plain = MasterAvatarCard.heightFor(context);
            withCaption = MasterAvatarCard.heightFor(context, withCaption: true);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(withCaption, greaterThan(plain));
  });
}

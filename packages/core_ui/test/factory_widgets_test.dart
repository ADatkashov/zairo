import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: factoryLightTheme(), home: Scaffold(body: Center(child: child)));

void main() {
  group('formatFactoryAmount', () {
    test('groups the whole part into thousands with a space', () {
      expect(formatFactoryAmount(12400), '12 400');
      expect(formatFactoryAmount(6000), '6 000');
      expect(formatFactoryAmount(999), '999');
      expect(formatFactoryAmount(1000000), '1 000 000');
    });

    test('rounds fractional amounts', () {
      expect(formatFactoryAmount(1999.6), '2 000');
    });
  });

  testWidgets('FactoryPriceText renders the prefix, grouped amount and currency', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryPriceText(amount: 15000, prefix: 'from ')));

    expect(find.text('from '), findsOneWidget);
    expect(find.text('15 000 ₸'), findsOneWidget);
  });

  testWidgets('FactoryPriceText uses an explicit currencySymbol instead of the regional default',
      (tester) async {
    await tester.pumpWidget(_wrap(const FactoryPriceText(amount: 15000, currencySymbol: r'$')));

    expect(find.text(r'15 000 $'), findsOneWidget);
  });

  testWidgets('FactoryRatingLabel exposes a full semantic label for screen readers', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryRatingLabel(rating: 4.9, reviewCount: 212)));

    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('(212)'), findsOneWidget);
    expect(find.bySemanticsLabel('4.9 out of 5, 212 reviews'), findsOneWidget);
  });

  testWidgets('FactoryChip reports selected state to semantics and responds to taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(FactoryChip(label: 'Today', selected: true, onTap: () => tapped = true)));

    expect(find.text('Today'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(FactoryChip));
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);

    await tester.tap(find.byType(FactoryChip));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryTimeSlot ignores taps and shows strikethrough when unavailable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(FactoryTimeSlot(
      label: '19:00',
      state: FactoryTimeSlotState.unavailable,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.byType(FactoryTimeSlot));
    expect(tapped, isFalse, reason: 'an unavailable slot must not be tappable');

    final text = tester.widget<Text>(find.text('19:00'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('FactoryTimeSlot responds normally when available', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(FactoryTimeSlot(label: '18:00', onTap: () => tapped = true)));

    await tester.tap(find.byType(FactoryTimeSlot));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryBadge renders its label', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryBadge(label: 'Available today', variant: FactoryBadgeVariant.available)));
    expect(find.text('Available today'), findsOneWidget);
  });

  testWidgets('FactoryBadge renders the error variant', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryBadge(label: 'Cancelled', variant: FactoryBadgeVariant.error)));
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('FactoryProviderCard shows title, rating, price and toggles favorite', (tester) async {
    var favoriteState = false;
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => FactoryProviderCard(
        title: 'Aigerim Beauty Studio',
        rating: 4.9,
        reviewCount: 212,
        metaText: '1.2 km',
        priceFrom: 8000,
        isFavorite: favoriteState,
        onFavoriteToggle: (v) => setState(() => favoriteState = v),
      ),
    )));

    expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('FactoryProviderCard calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(FactoryProviderCard(title: 'Nail Bar 21', onTap: () => tapped = true)));

    await tester.tap(find.byType(FactoryProviderCard));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryProviderCard does not overflow a narrow vertical card with a long availability label',
      (tester) async {
    // Regression test: a horizontally-scrolling discovery rail sizes cards
    // around 160-170px wide — price + a longer badge used to overflow the
    // footer row (see provider_card.dart's Wrap, not Row).
    await tester.pumpWidget(_wrap(const FactoryProviderCard(
      title: 'Aigerim Beauty Studio',
      priceFrom: 8000,
      availabilityLabel: 'Available today',
      layout: FactoryProviderCardLayout.vertical,
      width: 168,
    )));

    expect(tester.takeException(), isNull);
    expect(find.text('Available today'), findsOneWidget);
  });

  testWidgets('ServiceRow shows the grouped price', (tester) async {
    await tester.pumpWidget(_wrap(const ServiceRow(title: 'Balayage colouring', metaText: '90 min', price: 15000)));

    expect(find.text('Balayage colouring'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('15 000 ₸'), findsOneWidget);
  });

  testWidgets('ServiceRow shows a check icon and reports selected state to semantics when selected',
      (tester) async {
    await tester.pumpWidget(_wrap(const ServiceRow(
      title: 'Balayage colouring',
      metaText: '90 min',
      price: 15000,
      selected: true,
    )));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(ServiceRow));
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  });

  testWidgets('FactoryEmptyState only shows the action when both label and callback are given', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryEmptyState(
      icon: Icons.calendar_today_rounded,
      title: 'No available times today',
      message: 'Try another date.',
    )));
    expect(find.byType(OutlinedButton), findsNothing);

    var tapped = false;
    await tester.pumpWidget(_wrap(FactoryEmptyState(
      icon: Icons.calendar_today_rounded,
      title: 'No available times today',
      message: 'Try another date.',
      actionLabel: 'Try tomorrow',
      onAction: () => tapped = true,
    )));
    await tester.tap(find.text('Try tomorrow'));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryErrorState surfaces a human message and a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(FactoryErrorState(
      message: "Couldn't load your bookings.",
      onRetry: () => retried = true,
    )));

    expect(find.text("Couldn't load your bookings."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('FactoryAvatar shows initials when no image is given', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryAvatar(initials: 'AS')));
    expect(find.text('AS'), findsOneWidget);
  });

  testWidgets('FactorySkeleton renders a static block when reduce-motion is requested', (tester) async {
    // The MediaQuery override must sit inside MaterialApp's tree — MaterialApp
    // builds its own MediaQuery from the test View, which would otherwise
    // shadow one provided above it.
    await tester.pumpWidget(_wrap(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const FactorySkeleton(width: 40, height: 12),
      ),
    ));
    // Should build without an active AnimationController driving frames —
    // scoped to FactorySkeleton's own subtree, since MaterialApp's
    // machinery elsewhere in the tree has unrelated AnimatedBuilders of
    // its own.
    expect(find.byType(FactorySkeleton), findsOneWidget);
    expect(
      find.descendant(of: find.byType(FactorySkeleton), matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
  });
}

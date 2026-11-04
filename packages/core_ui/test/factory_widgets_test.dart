import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: factoryLightTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  _listSkeletonTests();
  narrowPhoneTests();
  _denseButtonTests();
  _authBrandTests();
  _settingsGroupTests();
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

  testWidgets(
    'FactoryPriceText renders the prefix, grouped amount and currency',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryPriceText(amount: 15000, prefix: 'from ')),
      );

      expect(find.text('from '), findsOneWidget);
      expect(find.text('15 000 ₸'), findsOneWidget);
    },
  );

  testWidgets(
    'FactoryPriceText uses an explicit currencySymbol instead of the regional default',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryPriceText(amount: 15000, currencySymbol: r'$')),
      );

      expect(find.text(r'15 000 $'), findsOneWidget);
    },
  );

  testWidgets(
    'FactoryRatingLabel exposes a full semantic label for screen readers',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryRatingLabel(rating: 4.9, reviewCount: 212)),
      );

      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('(212)'), findsOneWidget);
      expect(
        find.bySemanticsLabel('4.9 out of 5, 212 reviews'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'FactoryChip reports selected state to semantics and responds to taps',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactoryChip(
            label: 'Today',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(FactoryChip));
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);

      await tester.tap(find.byType(FactoryChip));
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'FactoryTimeSlot ignores taps and shows strikethrough when unavailable',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactoryTimeSlot(
            label: '19:00',
            state: FactoryTimeSlotState.unavailable,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(FactoryTimeSlot));
      expect(
        tapped,
        isFalse,
        reason: 'an unavailable slot must not be tappable',
      );

      final text = tester.widget<Text>(find.text('19:00'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    },
  );

  testWidgets('FactoryTimeSlot responds normally when available', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(FactoryTimeSlot(label: '18:00', onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(FactoryTimeSlot));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryTimeSlot is at least 44x44 so it is easy to tap', (tester) async {
    await tester.pumpWidget(_wrap(FactoryTimeSlot(label: '9:00', onTap: () {})));

    final size = tester.getSize(find.byType(FactoryTimeSlot));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  testWidgets('FactoryButton tonal uses the primary tint with the strong label colour', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(FactoryButton(label: 'Reschedule', variant: FactoryButtonVariant.tonal, onPressed: () => tapped = true)),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final style = button.style!;
    expect(style.backgroundColor!.resolve({}), FactoryColors.light.primaryTint);
    expect(style.foregroundColor!.resolve({}), FactoryColors.light.primaryStrong);

    await tester.tap(find.byType(FactoryButton));
    expect(tapped, isTrue);
  });

  testWidgets('FactoryChip selected is a tint with a check mark, not a solid fill', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryChip(label: 'Manicure', selected: true)));

    final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration as BoxDecoration;
    expect(box.color, FactoryColors.light.primaryTint);
    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);

    await tester.pumpWidget(_wrap(const FactoryChip(label: 'Manicure')));
    expect(find.byIcon(Symbols.check_rounded), findsNothing);
  });

  testWidgets('a selected FactoryChip with its own icon shows the check as well', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryChip(label: '5', icon: Symbols.star_rounded, selected: true)));
    expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.star_rounded), findsOneWidget);

    await tester.pumpWidget(_wrap(const FactoryChip(label: '5', icon: Symbols.star_rounded)));
    expect(find.byIcon(Symbols.check_rounded), findsNothing);
  });

  testWidgets('FactoryChip draws its icon outlined by default and solid with iconFilled', (tester) async {
    await tester.pumpWidget(_wrap(const FactoryChip(label: '5', icon: Symbols.star_rounded)));
    expect(tester.widget<Icon>(find.byIcon(Symbols.star_rounded)).fill, 0);

    await tester.pumpWidget(_wrap(const FactoryChip(label: '5', icon: Symbols.star_rounded, iconFilled: true)));
    expect(tester.widget<Icon>(find.byIcon(Symbols.star_rounded)).fill, 1);
  });

  testWidgets('input fields use the tonal fill with a hairline and a 2px focus ring', (tester) async {
    final theme = factoryLightTheme().inputDecorationTheme;
    expect(theme.filled, isTrue);
    expect(theme.fillColor, FactoryColors.light.surfaceAlt);
    expect((theme.enabledBorder as OutlineInputBorder).borderSide.color, FactoryColors.light.border);
    expect((theme.focusedBorder as OutlineInputBorder).borderSide.width, 2);
    expect((theme.errorBorder as OutlineInputBorder).borderSide.color, FactoryColors.light.error);
  });

  testWidgets('FactoryPhotoPlaceholder shows the category icon, and nothing without one', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 160,
          height: 128,
          child: FactoryPhotoPlaceholder(icon: Symbols.content_cut_rounded, color: FactoryColors.light.coral, tint: FactoryColors.light.coralTint),
        ),
      ),
    );
    expect(find.byIcon(Symbols.content_cut_rounded), findsOneWidget);
    // The icon is drawn inside a box that scales with the slot, never past 56.
    expect(tester.getSize(find.byType(FittedBox)).height, inInclusiveRange(40, 56));

    // A small side-photo slot gets a smaller icon, still inside the slot.
    await tester.pumpWidget(
      _wrap(const SizedBox(width: 84, height: 84, child: FactoryPhotoPlaceholder(icon: Symbols.content_cut_rounded))),
    );
    expect(tester.getSize(find.byType(FittedBox)).height, lessThan(40));

    await tester.pumpWidget(_wrap(const SizedBox(width: 160, height: 128, child: FactoryPhotoPlaceholder())));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('FactoryProviderCard without a photo falls back to the category placeholder', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 168,
          child: FactoryProviderCard(
            title: 'Studio',
            placeholderIcon: Symbols.directions_car_filled_rounded,
            categoryLabel: 'Auto',
            categoryColor: FactoryColors.light.lavender,
            categoryTint: FactoryColors.light.lavenderTint,
          ),
        ),
      ),
    );

    expect(find.byType(FactoryPhotoPlaceholder), findsOneWidget);
    expect(find.byIcon(Symbols.directions_car_filled_rounded), findsOneWidget);
  });

  testWidgets('FactoryTimeSlot keeps its own width inside a Wrap instead of filling the row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FactoryTimeSlot(label: '10:00'),
              FactoryTimeSlot(label: '12:00'),
              FactoryTimeSlot(label: '14:30', state: FactoryTimeSlotState.selected),
            ],
          ),
        ),
      ),
    );

    final slots = find.byType(FactoryTimeSlot);
    // Three slots fit on one row, each far narrower than the 300px offered.
    for (var i = 0; i < 3; i++) {
      expect(tester.getSize(slots.at(i)).width, lessThan(100));
      expect(tester.getSize(slots.at(i)).height, greaterThanOrEqualTo(44));
    }
    expect(tester.getTopLeft(slots.at(0)).dy, tester.getTopLeft(slots.at(2)).dy);
  });

  testWidgets('FactoryProviderCard shows a Book button that acts on its own, not as a card tap', (tester) async {
    var cardTaps = 0;
    var bookTaps = 0;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 168,
          child: FactoryProviderCard(
            title: 'Studio',
            onTap: () => cardTaps++,
            actionLabel: 'Book',
            onAction: () => bookTaps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Book'));
    expect(bookTaps, 1);
    expect(cardTaps, 0);

    // The button is a full phone tap target.
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Studio'));
    expect(cardTaps, 1);
  });

  testWidgets('the Book button on a provider card is the filled brand-colour button, not a pale one', (tester) async {
    await tester.pumpWidget(
      _wrap(SizedBox(width: 168, child: FactoryProviderCard(title: 'Studio', actionLabel: 'Book', onAction: () {}))),
    );

    // Primary leaves the colours to the theme; the tonal variant would have set its own pale tint.
    final fill = tester.widget<Material>(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)).first);
    expect(fill.color, FactoryColors.light.primary);
    expect(fill.color, isNot(FactoryColors.light.primaryTint));
  });

  testWidgets('FactoryProviderCard has no button unless it is given both a label and an action', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(width: 168, child: FactoryProviderCard(title: 'Studio', actionLabel: 'Book'))));
    expect(find.byType(FilledButton), findsNothing);

    await tester.pumpWidget(_wrap(SizedBox(width: 168, child: FactoryProviderCard(title: 'Studio', onAction: () {}))));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('FactoryBadge renders its label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryBadge(
          label: 'Available today',
          variant: FactoryBadgeVariant.available,
        ),
      ),
    );
    expect(find.text('Available today'), findsOneWidget);
  });

  testWidgets('FactoryBadge renders the error variant', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryBadge(
          label: 'Cancelled',
          variant: FactoryBadgeVariant.error,
        ),
      ),
    );
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets(
    'FactoryProviderCard shows title, rating, price and toggles favorite',
    (tester) async {
      var favoriteState = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => FactoryProviderCard(
              title: 'Aigerim Beauty Studio',
              rating: 4.9,
              reviewCount: 212,
              metaText: '1.2 km',
              priceFrom: 8000,
              isFavorite: favoriteState,
              onFavoriteToggle: (v) => setState(() => favoriteState = v),
            ),
          ),
        ),
      );

      expect(find.text('Aigerim Beauty Studio'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      // Symbols.favorite_rounded is one IconData regardless of fill state —
      // solid vs outline is the Icon widget's `fill` value, not a different
      // icon identity the way classic Icons.favorite/favorite_border were.
      expect(find.byIcon(Symbols.favorite_rounded), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
        0,
      );

      await tester.tap(find.byIcon(Symbols.favorite_rounded));
      await tester.pump();

      expect(
        tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
        1,
      );
    },
  );

  testWidgets(
    'FactoryProviderCard forwards caller-supplied favorite semantic labels, not the English fallback',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryProviderCard(
            title: 'Aigerim Beauty Studio',
            isFavorite: false,
            onFavoriteToggle: (_) {},
            favoriteAddSemanticLabel: 'Таңдаулыларға қосу',
            favoriteRemoveSemanticLabel: 'Таңдаулылардан алып тастау',
          ),
        ),
      );

      final semantics = tester.getSemantics(
        find.byIcon(Symbols.favorite_rounded),
      );
      expect(semantics.label, 'Таңдаулыларға қосу');
    },
  );

  testWidgets('FactoryProviderCard calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        FactoryProviderCard(title: 'Nail Bar 21', onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.byType(FactoryProviderCard));
    expect(tapped, isTrue);
  });

  testWidgets(
    'FactoryProviderCard does not overflow a narrow vertical card with a long availability label',
    (tester) async {
      // Regression test: a horizontally-scrolling discovery rail sizes cards
      // around 160-170px wide — price + a longer badge used to overflow the
      // footer row (see provider_card.dart's Wrap, not Row).
      await tester.pumpWidget(
        _wrap(
          const FactoryProviderCard(
            title: 'Aigerim Beauty Studio',
            priceFrom: 8000,
            availabilityLabel: 'Available today',
            layout: FactoryProviderCardLayout.vertical,
            width: 168,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Available today'), findsOneWidget);
    },
  );

  testWidgets('FactoryServiceCard shows the grouped price', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryServiceCard(
          title: 'Balayage colouring',
          metaText: '90 min',
          price: 15000,
        ),
      ),
    );

    expect(find.text('Balayage colouring'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('15 000 ₸'), findsOneWidget);
  });

  testWidgets(
    'FactoryServiceCard shows a check icon and reports selected state to semantics when selected',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryServiceCard(
            title: 'Balayage colouring',
            metaText: '90 min',
            price: 15000,
            selected: true,
          ),
        ),
      );

      expect(find.byIcon(Symbols.check_circle_rounded), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(FactoryServiceCard));
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    },
  );

  testWidgets(
    'FactoryEmptyState only shows the action when both label and callback are given',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryEmptyState(
            icon: Icons.calendar_today_rounded,
            title: 'No available times today',
            message: 'Try another date.',
          ),
        ),
      );
      expect(find.byType(FactoryButton), findsNothing);

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactoryEmptyState(
            icon: Icons.calendar_today_rounded,
            title: 'No available times today',
            message: 'Try another date.',
            actionLabel: 'Try tomorrow',
            onAction: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try tomorrow'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('FactoryErrorState surfaces a human message and a retry action', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        FactoryErrorState(
          message: "Couldn't load your bookings.",
          onRetry: () => retried = true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your bookings."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('FactoryAvatar shows initials when no image is given', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FactoryAvatar(initials: 'AS')));
    expect(find.text('AS'), findsOneWidget);
  });

  testWidgets(
    'FactorySkeleton renders a static block when reduce-motion is requested',
    (tester) async {
      // The MediaQuery override must sit inside MaterialApp's tree — MaterialApp
      // builds its own MediaQuery from the test View, which would otherwise
      // shadow one provided above it.
      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const FactorySkeleton(width: 40, height: 12),
          ),
        ),
      );
      // Should build without an active AnimationController driving frames —
      // scoped to FactorySkeleton's own subtree, since MaterialApp's
      // machinery elsewhere in the tree has unrelated AnimatedBuilders of
      // its own.
      expect(find.byType(FactorySkeleton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FactorySkeleton),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'FactoryLogomark renders at both the dashed and flat-block size variants',
    (tester) async {
      await tester.pumpWidget(_wrap(const FactoryLogomark(size: 56)));
      expect(find.byType(FactoryLogomark), findsOneWidget);

      // Below ~32px the fourth block swaps from dashed-open to a flat block —
      // both must render without throwing, not just the default size.
      await tester.pumpWidget(_wrap(const FactoryLogomark(size: 16)));
      expect(find.byType(FactoryLogomark), findsOneWidget);
    },
  );

  testWidgets(
    'FactoryButton shows a spinner instead of the label and disables itself while loading',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactoryButton(
            label: 'Book',
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        ),
      );

      expect(find.text('Book'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(tapped, isFalse);
    },
  );

  testWidgets('FactoryButton renders the danger variant and responds to taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        FactoryButton(
          label: 'Delete account',
          variant: FactoryButtonVariant.danger,
          onPressed: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Delete account'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'FactoryButton textDanger renders as a TextButton, not a filled one',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryButton(
            label: 'Cancel booking',
            variant: FactoryButtonVariant.textDanger,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets(
    'FactoryIconButton exposes its label as a tooltip/semantic label',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FactoryIconButton(
            icon: Symbols.favorite_rounded,
            onPressed: () {},
            semanticLabel: 'Add to favorites',
          ),
        ),
      );

      expect(find.byTooltip('Add to favorites'), findsOneWidget);
    },
  );

  testWidgets(
    'FactoryTextField always renders a persistent label, not a placeholder-only hint',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactoryTextField(
            label: 'Phone number',
            hint: '+7 700 000 00 00',
          ),
        ),
      );

      expect(find.text('Phone number'), findsOneWidget);
    },
  );

  testWidgets('FactoryTextField surfaces errorText', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryTextField(label: 'Promo code', errorText: 'Invalid code'),
      ),
    );

    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets(
    'FactoryTextField participates in Form validation via validator',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: FactoryTextField(
              label: 'Email',
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Invalid email'
                  : null,
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Invalid email'), findsOneWidget);
    },
  );

  testWidgets(
    'FactorySearchField shows a filter action only when onFilterTap is given',
    (tester) async {
      var filterTapped = false;
      await tester.pumpWidget(
        _wrap(
          FactorySearchField(
            hint: 'Search salons',
            onFilterTap: () => filterTapped = true,
          ),
        ),
      );

      expect(find.byIcon(Symbols.tune_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.tune_rounded));
      expect(filterTapped, isTrue);
    },
  );

  testWidgets(
    'FactorySearchField shows a clear button only while it holds text',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var cleared = 0;
      await tester.pumpWidget(
        _wrap(
          FactorySearchField(
            controller: controller,
            hint: 'Search salons',
            onCleared: () => cleared++,
          ),
        ),
      );

      expect(find.byIcon(Symbols.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'nails');
      await tester.pump();
      expect(find.byIcon(Symbols.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.close_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cleared, 1);
      expect(find.byIcon(Symbols.close_rounded), findsNothing);
    },
  );

  testWidgets('FactoryButton wraps a long label in a narrow parent instead of overflowing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 160,
          child: FactoryButton(
            label: 'A very long button label that cannot fit on one line',
            variant: FactoryButtonVariant.text,
            onPressed: null,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('FactoryCard calls onTap and renders its child', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        FactoryCard(
          onTap: () => tapped = true,
          child: const Text('Card content'),
        ),
      ),
    );

    expect(find.text('Card content'), findsOneWidget);
    await tester.tap(find.text('Card content'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'FactorySectionHeader shows the action only when both label and callback are given',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const FactorySectionHeader(title: 'Popular categories')),
      );
      expect(find.byType(TextButton), findsNothing);

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactorySectionHeader(
            title: 'Popular categories',
            actionLabel: 'See all',
            onActionTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('See all'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('FactorySectionHeader keeps its action at the far edge even inside a start-aligned Column', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FactorySectionHeader(title: 'Businesses', actionLabel: 'Open', onActionTap: () {}),
            ],
          ),
        ),
      ),
    );

    // A Column with start alignment gives its children loose width; the header used to shrink to its content
    // and leave "Open" glued to the title instead of at the right edge.
    final header = tester.getRect(find.byType(FactorySectionHeader));
    expect(header.width, 360);
    expect(tester.getRect(find.byType(TextButton)).right, closeTo(header.right, 0.5));
  });

  testWidgets('FactoryAppBar renders its title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: const Scaffold(appBar: FactoryAppBar(title: 'Bookings')),
      ),
    );
    expect(find.text('Bookings'), findsOneWidget);
  });

  testWidgets('FactoryBottomNavigation reports the tapped destination index', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _wrap(
        FactoryBottomNavigation(
          destinations: const [
            FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
            FactoryNavDestination(icon: Icons.search_rounded, label: 'Search'),
          ],
          selectedIndex: 0,
          onDestinationSelected: (index) => selected = index,
        ),
      ),
    );

    await tester.tap(find.text('Search'));
    expect(selected, 1);
  });

  testWidgets(
    'FactoryBottomNavigation fits five tabs with long labels on a phone width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          FactoryBottomNavigation(
            destinations: const [
              FactoryNavDestination(icon: Icons.dashboard_rounded, label: 'Dashboard'),
              FactoryNavDestination(icon: Icons.forum_rounded, label: 'Messages'),
              FactoryNavDestination(icon: Icons.campaign_rounded, label: 'Campaign Center'),
              FactoryNavDestination(icon: Icons.loyalty_rounded, label: 'Loyalty'),
              FactoryNavDestination(icon: Icons.more_horiz_rounded, label: 'More'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );

      // A RenderFlex overflow would be reported as a test exception.
      expect(tester.takeException(), isNull);
      expect(find.text('More'), findsOneWidget);
    },
  );

  testWidgets('FactoryBottomNavigation centre action sits in the middle, fires on tap and keeps tab indexes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    int? selected;
    var actionTaps = 0;
    await tester.pumpWidget(
      _wrap(
        FactoryBottomNavigation(
          destinations: const [
            FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
            FactoryNavDestination(icon: Icons.search_rounded, label: 'Search'),
            FactoryNavDestination(icon: Icons.calendar_month_rounded, label: 'Bookings'),
            FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
          ],
          selectedIndex: 0,
          onDestinationSelected: (i) => selected = i,
          centerAction: FactoryNavAction(icon: Icons.add_rounded, label: 'New booking', onTap: () => actionTaps++),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final centre = tester.getCenter(find.byIcon(Icons.add_rounded));
    expect(centre.dx, closeTo(195, 1), reason: 'centred on a 390px screen');
    expect(tester.getCenter(find.text('Search')).dx, lessThan(centre.dx));
    expect(tester.getCenter(find.text('Bookings')).dx, greaterThan(centre.dx));

    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(actionTaps, 1);
    expect(selected, isNull, reason: 'the action is not a tab');

    await tester.tap(find.text('Bookings'));
    expect(selected, 2, reason: 'indexes are those of the destinations list');
    expect(find.bySemanticsLabel('New booking'), findsOneWidget);
  });

  testWidgets('FactoryBottomNavigation keeps the centre action centred with three tabs (1 + action + 2)', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    int? selected;
    await tester.pumpWidget(
      _wrap(
        FactoryBottomNavigation(
          destinations: const [
            FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
            FactoryNavDestination(icon: Icons.calendar_month_rounded, label: 'Bookings'),
            FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
          ],
          selectedIndex: 0,
          onDestinationSelected: (i) => selected = i,
          centerAction: FactoryNavAction(icon: Icons.search_rounded, label: 'Find', visibleLabel: true, onTap: () {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final centre = tester.getCenter(find.byIcon(Icons.search_rounded));
    expect(centre.dx, closeTo(195, 1));
    expect(tester.getCenter(find.text('Home')).dx, lessThan(centre.dx));
    expect(tester.getCenter(find.text('Bookings')).dx, greaterThan(centre.dx));
    expect(tester.getCenter(find.text('Profile')).dx, greaterThan(tester.getCenter(find.text('Bookings')).dx));

    await tester.tap(find.text('Profile'));
    expect(selected, 2);
  });

  testWidgets('FactoryBottomNavigation: a lone tab beside the action keeps its natural width (no half-bar capsule), also at 320 px', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          FactoryBottomNavigation(
            destinations: const [
              FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
              FactoryNavDestination(icon: Icons.calendar_month_rounded, label: 'Bookings'),
              FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            centerAction: FactoryNavAction(icon: Icons.search_rounded, label: 'Find a service', visibleLabel: true, onTap: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$width px');

      final capsule = find.ancestor(of: find.text('Home'), matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(capsule).width, lessThan(100), reason: '$width px: the selected capsule hugs its tab');
      expect(find.text('Profile'), findsOneWidget);
      // The label is whole, not ellipsized: it fits in its natural width.
      expect(tester.getSize(find.text('Profile')).width, greaterThan(30), reason: '$width px');
    }
  });

  testWidgets('FactoryBottomNavigation can write the centre action\'s name under the button; the text acts too', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var actionTaps = 0;
    Widget bar({required bool visibleLabel}) => _wrap(
      FactoryBottomNavigation(
        destinations: const [
          FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
          FactoryNavDestination(icon: Icons.search_rounded, label: 'Search'),
          FactoryNavDestination(icon: Icons.calendar_month_rounded, label: 'Bookings'),
          FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
        ],
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        centerAction: FactoryNavAction(
          icon: Icons.add_rounded,
          label: 'New booking',
          visibleLabel: visibleLabel,
          onTap: () => actionTaps++,
        ),
      ),
    );

    // Off by default: the name is only for screen readers.
    await tester.pumpWidget(bar(visibleLabel: false));
    expect(find.text('New booking'), findsNothing);
    expect(find.bySemanticsLabel('New booking'), findsOneWidget);

    await tester.pumpWidget(bar(visibleLabel: true));
    expect(tester.takeException(), isNull);
    expect(find.text('New booking'), findsOneWidget);
    // On the same line as the tab labels and centred under the button, so it reads as part of the bar.
    expect(tester.getCenter(find.text('New booking')).dy, closeTo(tester.getCenter(find.text('Search')).dy, 1));
    expect(tester.getCenter(find.text('New booking')).dx, closeTo(195, 1));
    // Still announced once, not twice.
    expect(find.bySemanticsLabel('New booking'), findsOneWidget);

    await tester.tap(find.text('New booking'));
    expect(actionTaps, 1);
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(actionTaps, 2);
  });

  testWidgets('FactoryBottomNavigation centre action with quick actions opens a fan, picks one and closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Scaffold(
          bottomNavigationBar: FactoryBottomNavigation(
            destinations: const [
              FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
              FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
            ],
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            centerAction: FactoryNavAction(
              icon: Icons.add_rounded,
              label: 'Quick actions',
              quickActions: [
                FactoryNavQuickAction(icon: Icons.event_available_rounded, label: 'Book', onTap: () => picked.add('book')),
                FactoryNavQuickAction(icon: Icons.chat_bubble_rounded, label: 'Messages', onTap: () => picked.add('msg')),
                FactoryNavQuickAction(icon: Icons.favorite_rounded, label: 'Favorites', onTap: () => picked.add('fav')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Messages'), findsNothing, reason: 'closed by default');

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    // Fanned out left-to-right above the button.
    expect(tester.getCenter(find.text('Book')).dx, lessThan(tester.getCenter(find.text('Messages')).dx));
    expect(tester.getCenter(find.text('Favorites')).dx, greaterThan(tester.getCenter(find.text('Messages')).dx));
    // While open the dimmed page hides the real button, so a copy is drawn on top.
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
    expect(
      tester.getCenter(find.text('Messages')).dy,
      lessThan(tester.getCenter(find.byIcon(Icons.add_rounded).last).dy),
    );

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(picked, ['msg']);
    expect(find.text('Messages'), findsNothing, reason: 'the fan closes after a pick');

    // Re-open, then dismiss by tapping the dimmed page.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(find.text('Favorites'), findsNothing);
    expect(picked, ['msg']);
  });

  testWidgets('system Back closes an open fan first and only then leaves the screen', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final openStates = <bool>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: factoryLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: const Text('second page'),
                    bottomNavigationBar: FactoryBottomNavigation(
                      destinations: const [
                        FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
                        FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile'),
                      ],
                      selectedIndex: 0,
                      onDestinationSelected: (_) {},
                      onFanOpenChanged: openStates.add,
                      centerAction: FactoryNavAction(
                        icon: Icons.add_rounded,
                        label: 'Quick actions',
                        quickActions: [FactoryNavQuickAction(icon: Icons.chat_bubble_rounded, label: 'Messages', onTap: () {})],
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsOneWidget);
    expect(openStates, [true]);

    // First Back: the fan closes, the page stays.
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsNothing);
    expect(find.text('second page'), findsOneWidget);
    expect(openStates, [true, false]);

    // Second Back: leaves the page as usual.
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsNothing);
  });

  testWidgets('FactoryBottomNavigation draws a count badge only when there is something to count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FactoryBottomNavigation(
          destinations: const [
            FactoryNavDestination(icon: Icons.home_rounded, label: 'Home'),
            FactoryNavDestination(icon: Icons.person_rounded, label: 'Profile', badgeCount: 3),
            FactoryNavDestination(icon: Icons.forum_rounded, label: 'Chats', badgeCount: 12),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('9+'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile, 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
  });

  testWidgets(
    'FactoryLoadingState shows an optional message alongside the spinner',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryLoadingState(message: 'Loading your bookings…')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your bookings…'), findsOneWidget);
    },
  );

  testWidgets('showFactoryDialog renders the title, message and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showFactoryDialog(
              context: context,
              title: 'Cancel booking?',
              message: 'This can’t be undone.',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Confirm'),
                ),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel booking?'), findsOneWidget);
    expect(find.text('This can’t be undone.'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel booking?'), findsNothing);
  });

  testWidgets(
    'showFactoryDialog renders custom content instead of message when both would otherwise apply',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: factoryLightTheme(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFactoryDialog(
                context: context,
                title: 'Add a business',
                content: const TextField(key: Key('name-field')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add a business'), findsOneWidget);
      expect(find.byKey(const Key('name-field')), findsOneWidget);
    },
  );

  testWidgets(
    'FactoryCategoryTile reports selected state and responds to taps',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactoryCategoryTile(
            icon: Icons.content_cut_rounded,
            label: 'Beauty',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Beauty'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(FactoryCategoryTile));
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      await tester.tap(find.byType(FactoryCategoryTile));
      expect(tapped, isTrue);
    },
  );

  testWidgets('FactoryStatTile renders a value over a label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FactoryStatTile(
          value: '12',
          label: 'Bookings',
          icon: Icons.event_note_outlined,
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
  });

  testWidgets(
    'FactorySelectableTile shows a check icon and reports selected state to semantics',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          FactorySelectableTile(
            title: 'Aigerim K.',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Symbols.check_circle_rounded), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(FactorySelectableTile));
      expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);

      await tester.tap(find.byType(FactorySelectableTile));
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'FactorySelectableTile renders leading, subtitle and trailing widgets',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactorySelectableTile(
            title: 'Toyota Camry',
            subtitle: Text('A123BC 02'),
            leading: Icon(Icons.directions_car_rounded),
            trailing: Icon(Icons.delete_outline),
          ),
        ),
      );

      expect(find.text('Toyota Camry'), findsOneWidget);
      expect(find.text('A123BC 02'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    },
  );

  testWidgets('showFactoryBottomSheet renders its content with a drag handle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showFactoryBottomSheet(
              context: context,
              builder: (context) => const Text('Filters'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.byType(FactoryBottomSheet), findsOneWidget);
  });

  testWidgets('showFactoryBottomSheet with scrollable: false gives the content a bounded height to scroll in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showFactoryBottomSheet(
              context: context,
              isScrollControlled: true,
              scrollable: false,
              builder: (context) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Header'),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(children: [for (var i = 0; i < 40; i++) Text('Row $i')]),
                      ),
                    ),
                    const Text('Pinned action'),
                  ],
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The handle + content aren't wrapped in a second scroll view, so the
    // header and the pinned action both stay visible beside the long body.
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Pinned action'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  group('currency display', () {
    Future<void> pumpPrice(WidgetTester tester, Widget price) => tester.pumpWidget(
          MaterialApp(theme: factoryLightTheme(), home: Scaffold(body: price)),
        );

    testWidgets('an ISO code is shown as its symbol, never as the raw code', (tester) async {
      await pumpPrice(tester, const FactoryPriceText(amount: 12400, currencySymbol: 'KZT'));
      expect(find.text('12 400 ₸'), findsOneWidget);

      await pumpPrice(tester, const FactoryPriceText(amount: 12400, currencySymbol: 'USD'));
      expect(find.text('12 400 \$'), findsOneWidget);
    });

    testWidgets('no currency falls back to the platform market (tenge)', (tester) async {
      await pumpPrice(tester, const FactoryPriceText(amount: 500));
      expect(find.text('500 ₸'), findsOneWidget);
    });

    test('formatFactoryMoney resolves codes, other markets and a missing currency', () {
      expect(formatFactoryMoney(12400, 'KZT'), '12 400 ₸');
      expect(formatFactoryMoney(12400, 'RUB'), '12 400 ₽');
      expect(formatFactoryMoney(12400, 'UZS'), "12 400 so'm");
      expect(formatFactoryMoney(12400, null), '12 400 ₸');
      expect(formatFactoryMoney(12400, 'XYZ'), '12 400 XYZ');
    });
  });
}

void _denseButtonTests() {
  testWidgets('dense FactoryButton is 36px high, regular is 48px', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: Scaffold(
          body: Column(
            children: [
              FactoryButton(key: const Key('dense'), dense: true, label: 'Approve', onPressed: () {}),
              FactoryButton(key: const Key('regular'), label: 'Approve', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('dense'))).height, 36);
    expect(tester.getSize(find.byKey(const Key('regular'))).height, 48);
  });
}

void _authBrandTests() {
  group('FactoryAuthBrand', () {
    testWidgets('shows the mark with an optional title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(const FactoryAuthBrand(title: 'Welcome', subtitle: 'Sign in to continue')));

      expect(find.byType(FactoryLogomark), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
    });

    testWidgets('is just the mark without text, in both themes, without overflow', (tester) async {
      for (final theme in [factoryLightTheme(), factoryDarkTheme()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: Center(child: FactoryAuthBrand())),
          ),
        );
        expect(find.byType(FactoryLogomark), findsOneWidget);
        expect(find.byType(Text), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

void _settingsGroupTests() {
  group('FactorySettingsGroup', () {
    testWidgets('puts a hairline between rows only, not before the first', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FactorySettingsGroup(
            children: [
              ListTile(title: Text('One')),
              ListTile(title: Text('Two')),
              ListTile(title: Text('Three')),
            ],
          ),
        ),
      );

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('a single row has no divider', (tester) async {
      await tester.pumpWidget(_wrap(const FactorySettingsGroup(children: [ListTile(title: Text('Only'))])));

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('row taps still reach the row inside the card', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FactorySettingsGroup(
            children: [
              ListTile(
                leading: const FactoryIconBadge(icon: Icons.language),
                title: const Text('Language'),
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Language'));
      expect(taps, 1);
      expect(find.byIcon(Icons.language), findsOneWidget);
    });
  });
}

void narrowPhoneTests() {
  Future<void> pumpNarrow(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: app!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  group('narrow phone, large text', () {
    testWidgets('a section header moves its action under the title instead of overflowing', (tester) async {
      await pumpNarrow(
        tester,
        FactorySectionHeader(
          title: 'A fairly long section title',
          // Several actions go in a Wrap, so they flow onto a second line when one line isn't enough.
          trailing: Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () {}, child: const Text('Show removed')),
              TextButton(onPressed: () {}, child: const Text('Add')),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dialog taller than the screen scrolls', (tester) async {
      await pumpNarrow(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => FactoryDialog(
                title: 'Title',
                content: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 20; i++) Text('line $i')]),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('FactoryCategoryTile', () {
    testWidgets('its label is 72 wide unless the grid cell says otherwise', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryCategoryTile(icon: Icons.star_rounded, label: 'Beauty')),
      );
      expect(
        tester.getSize(find.ancestor(of: find.text('Beauty'), matching: find.byType(SizedBox)).first).width,
        FactoryCategoryTile.labelWidth,
      );

      await tester.pumpWidget(
        _wrap(const FactoryCategoryTile(icon: Icons.star_rounded, label: 'Beauty', labelMaxWidth: 60)),
      );
      expect(
        tester.getSize(find.ancestor(of: find.text('Beauty'), matching: find.byType(SizedBox)).first).width,
        60,
      );
    });

    testWidgets('a dense tile has a smaller label, and a gridded tile no side padding', (tester) async {
      await tester.pumpWidget(
        _wrap(const FactoryCategoryTile(icon: Icons.star_rounded, label: 'Beauty')),
      );
      final normal = tester.widget<Text>(find.text('Beauty')).style?.fontSize;

      await tester.pumpWidget(
        _wrap(const FactoryCategoryTile(icon: Icons.star_rounded, label: 'Beauty', labelMaxWidth: 60, dense: true)),
      );
      expect(tester.widget<Text>(find.text('Beauty')).style?.fontSize, 12);
      expect(normal, isNot(12));
      // 60 wide label, no 4px side padding: the tile is exactly as wide as its cell.
      expect(tester.getSize(find.byType(FactoryCategoryTile)).width, 60);
    });
  });

  testWidgets('a stat tile shows zero in grey and a real count in the normal text colour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: const Scaffold(
          body: Row(children: [FactoryStatTile(value: '0', label: 'Booked'), FactoryStatTile(value: '7', label: 'Viewed')]),
        ),
      ),
    );
    final zero = tester.widget<Text>(find.text('0'));
    final seven = tester.widget<Text>(find.text('7'));
    expect(zero.style?.color, FactoryColors.light.textTertiary);
    expect(seven.style?.color, isNot(FactoryColors.light.textTertiary));
  });

  testWidgets('the show/hide eye of a password field fits inside the field, with room around it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: FactoryTextField(label: 'Password', obscureText: true))),
      ),
    );
    final field = tester.getRect(find.byType(TextField));
    final eye = tester.getRect(find.byType(IconButton));
    expect(eye.height, lessThanOrEqualTo(field.height - 12), reason: 'not taller than the field');
    expect(eye.right, lessThanOrEqualTo(field.right - 4), reason: 'not past its edge');
    expect(eye.top, greaterThan(field.top));
    expect(eye.bottom, lessThan(field.bottom));
  });
}

void _listSkeletonTests() {
  testWidgets('FactoryListSkeleton draws the asked number of card rows and no spinner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: const Scaffold(body: FactoryListSkeleton(itemCount: 3)),
      ),
    );
    // 3 rows x (picture + two lines).
    expect(find.byType(FactorySkeleton), findsNWidgets(9));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('FactoryListSkeleton does not overflow a 320 px phone and is hidden from screen readers', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: factoryLightTheme(),
        home: const Scaffold(body: FactoryListSkeleton()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(FactoryListSkeleton), matching: find.byType(ExcludeSemantics)), findsWidgets);
  });
}

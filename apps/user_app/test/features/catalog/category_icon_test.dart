import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/catalog/presentation/category_icon.dart';

void main() {
  testWidgets(
    'beauty/auto/cleaning keep the design board\'s pinned accent colors',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: factoryLightTheme(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final colors = capturedContext.factoryColors;
      expect(colorForCategory(capturedContext, 'beauty')?.color, colors.coral);
      expect(colorForCategory(capturedContext, 'auto')?.color, colors.lavender);
      expect(colorForCategory(capturedContext, 'cleaning')?.color, colors.mint);
    },
  );

  testWidgets(
    'every other real category also gets a color, cycling the same three accents',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: factoryLightTheme(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const knownCodes = [
        'medicine',
        'home_repair',
        'sport_fitness',
        'education',
        'kids',
        'animals',
        'photo_video',
        'weddings',
        'legal',
        'it_digital',
        'food',
        'fashion',
        'real_estate',
        'tourism',
        'household_services',
        'entertainment',
        'business_services',
        'events',
      ];
      final colors = capturedContext.factoryColors;
      final accents = {colors.coral, colors.lavender, colors.mint};
      for (final code in knownCodes) {
        final accent = colorForCategory(capturedContext, code);
        expect(accent, isNotNull, reason: '$code should have an accent color');
        expect(accents, contains(accent!.color));
      }

      // A code outside the whole known taxonomy still renders (neutral
      // fallback), rather than this function inventing a color for it.
      expect(
        colorForCategory(capturedContext, 'brand_new_admin_category'),
        isNull,
      );
    },
  );
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Mirrors apps/user_app's identical `category_icon.dart` — icons aren't
/// part of the master catalog (a presentation detail, not taxonomy), so
/// this is a small, forward-compatible local lookup, not a hardcoded
/// `if (vertical == "beauty")` business-logic branch: unknown codes still
/// render, just with a generic icon/color, instead of failing.
IconData iconForCategory(String code) => switch (code) {
      'beauty' => Icons.content_cut_rounded,
      'auto' => Icons.directions_car_filled_rounded,
      'cleaning' => Icons.cleaning_services_rounded,
      _ => Icons.storefront_outlined,
    };

/// The (icon color, chip background) pair Business Admin tags a business's
/// category with — beauty/auto/cleaning each get one of the design
/// system's category accents (see `FactoryColors.categoryCoral` and
/// friends) so a mixed list of businesses reads at a glance. Anything else
/// falls back to the shared `accent`/`accentTint` roles rather than
/// inventing a fourth accent per unknown code.
(Color, Color) categoryAccentFor(FactoryColors colors, String code) => switch (code) {
      'beauty' => (colors.categoryCoral, colors.categoryCoralTint),
      'auto' => (colors.categoryLavender, colors.categoryLavenderTint),
      'cleaning' => (colors.categoryMint, colors.categoryMintTint),
      _ => (colors.accent, colors.accentTint),
    };

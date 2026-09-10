import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Icons aren't part of the master catalog (a presentation detail, not
/// taxonomy) — this is a small, forward-compatible local lookup, not a
/// hardcoded `if (category == "beauty")` business-logic branch: unknown
/// codes still render, just with a generic icon, instead of failing. Shared
/// between Home's popular-categories row, the full category browser, and
/// provider cards' category badge so none of the three drift.
///
/// Uses `material_symbols_icons`' `Symbols.*_rounded` set rather than
/// Flutter's own bundled `Icons.*_rounded` — the Customer App Redesign
/// board's `.dc.html` renders every icon via `<span
/// class="material-symbols-rounded">content_cut</span>` (Google's Material
/// Symbols Rounded font), which is a visually distinct glyph set from
/// Flutter's classic Material Icons font even for an icon with the same
/// name (heavier, more rounded strokes) — `beauty`/`auto`/`cleaning` below
/// use the board's own icon names (`content_cut`, `directions_car_filled`,
/// `cleaning_services`) verbatim so these three render pixel-equivalent to
/// the mockup, not just semantically equivalent.
///
/// Covers all 21 codes the platform's top-level taxonomy actually seeds
/// (V41__seed_category_taxonomy.sql) — every real category gets its own
/// icon here, not just the original beauty/auto/cleaning three.
IconData iconForCategory(String code) => switch (code) {
  'beauty' => Symbols.content_cut_rounded,
  'medicine' => Symbols.medical_services_rounded,
  'auto' => Symbols.directions_car_filled_rounded,
  'home_repair' => Symbols.handyman_rounded,
  'sport_fitness' => Symbols.fitness_center_rounded,
  'education' => Symbols.school_rounded,
  'kids' => Symbols.child_care_rounded,
  'animals' => Symbols.pets_rounded,
  'photo_video' => Symbols.photo_camera_rounded,
  'weddings' => Symbols.favorite_rounded,
  'legal' => Symbols.gavel_rounded,
  'it_digital' => Symbols.computer_rounded,
  'food' => Symbols.restaurant_rounded,
  'fashion' => Symbols.checkroom_rounded,
  'real_estate' => Symbols.home_work_rounded,
  'tourism' => Symbols.flight_rounded,
  'household_services' => Symbols.room_service_rounded,
  'entertainment' => Symbols.sports_esports_rounded,
  'business_services' => Symbols.business_center_rounded,
  'events' => Symbols.celebration_rounded,
  'cleaning' => Symbols.cleaning_services_rounded,
  _ => Symbols.storefront_rounded,
};

/// Every category beyond the original beauty/auto/cleaning three, in the
/// master catalog's own seeded order (V41's `sort_order`) — cycled through
/// [colorForCategory]'s three accent colors below rather than left neutral.
/// The Customer App Redesign board only ever specified three accent colors
/// (coral/lavender/mint — there is no fourth token to reach for), so this
/// reuses that same palette instead of inventing new colors the design
/// system doesn't define.
const _accentCycleCodes = [
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

/// Per-category brand accent (Customer App Redesign board, 2026-09-05):
/// beauty/auto/cleaning keep the board's exact assignment, every other real
/// category cycles through the same three colors by its catalog position
/// (see [_accentCycleCodes]), and only a code outside the whole known set
/// (e.g. a brand-new admin-created category ahead of this list being
/// updated) falls back to `null` — [FactoryCategoryTile] then uses its
/// original neutral treatment rather than this guessing at a color.
({Color color, Color tint})? colorForCategory(
  BuildContext context,
  String code,
) {
  final colors = context.factoryColors;
  switch (code) {
    case 'beauty':
      return (color: colors.coral, tint: colors.coralTint);
    case 'auto':
      return (color: colors.lavender, tint: colors.lavenderTint);
    case 'cleaning':
      return (color: colors.mint, tint: colors.mintTint);
  }

  final index = _accentCycleCodes.indexOf(code);
  if (index == -1) return null;
  return switch (index % 3) {
    0 => (color: colors.coral, tint: colors.coralTint),
    1 => (color: colors.lavender, tint: colors.lavenderTint),
    _ => (color: colors.mint, tint: colors.mintTint),
  };
}

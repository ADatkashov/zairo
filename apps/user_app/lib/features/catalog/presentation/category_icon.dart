import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Icons aren't part of the master catalog (a presentation detail, not
/// taxonomy) — this is a small, forward-compatible local lookup, not a
/// hardcoded `if (category == "beauty")` business-logic branch: unknown
/// codes still render, just with a generic icon, instead of failing. Shared
/// between Home's popular-categories row and the full category browser so
/// the two don't drift.
IconData iconForCategory(String code) => switch (code) {
  'beauty' => Icons.content_cut_rounded,
  'auto' => Icons.directions_car_filled_rounded,
  'cleaning' => Icons.cleaning_services_rounded,
  _ => Icons.storefront_outlined,
};

/// Per-category brand accent (Customer App Redesign board, 2026-09-05) —
/// same forward-compatible shape as [iconForCategory]: a code outside this
/// small known set gets `null` and [FactoryCategoryTile] falls back to its
/// original neutral treatment, rather than inventing a color for a category
/// this mapping doesn't know about.
({Color color, Color tint})? colorForCategory(BuildContext context, String code) {
  final colors = context.factoryColors;
  return switch (code) {
    'beauty' => (color: colors.coral, tint: colors.coralTint),
    'auto' => (color: colors.lavender, tint: colors.lavenderTint),
    'cleaning' => (color: colors.mint, tint: colors.mintTint),
    _ => null,
  };
}

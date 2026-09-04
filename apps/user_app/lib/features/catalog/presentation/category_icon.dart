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

import 'package:flutter/animation.dart';

/// Motion tokens — confirms state changes, never performs. Every screen
/// transition, sheet, and selection animation should reach for one of
/// these three durations rather than a one-off number.
class FactoryMotion {
  const FactoryMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);

  /// M3-style emphasized-decelerate — confident, not bouncy.
  static const Curve standard = Cubic(0.2, 0, 0, 1);
}

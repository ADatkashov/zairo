import 'package:flutter/widgets.dart';

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

  /// Press feedback: buttons and cards scale to this while held.
  static const double pressScale = 0.98;

  /// Delay between items of a staggered reveal; cap the sequence at
  /// [staggerMaxItems] so long lists don't wait on their own animation.
  static const Duration stagger = Duration(milliseconds: 40);
  static const int staggerMaxItems = 6;

  /// Honors the platform "reduce motion" setting: returns [Duration.zero]
  /// when it is on, otherwise [duration].
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

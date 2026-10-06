import 'package:flutter/material.dart';

import 'factory_radius.dart';

/// Per-app temperament on top of the shared tokens: the consumer app is
/// roomy and rounded, business is clear and work-ready, platform is dense.
/// Pass one to `factoryLightTheme(profile: ...)`; widgets read it with
/// `context.factoryProfile`.
@immutable
class FactoryAppProfile extends ThemeExtension<FactoryAppProfile> {
  const FactoryAppProfile({required this.cardRadius, required this.rowHeight, required this.pagePadding});

  /// Corner radius for cards and Bento tiles.
  final double cardRadius;

  /// Minimum height of a list or table row.
  final double rowHeight;

  /// Horizontal page gutter.
  final double pagePadding;

  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

  static const consumer = FactoryAppProfile(cardRadius: FactoryRadius.xl, rowHeight: 64, pagePadding: 20);
  static const business = FactoryAppProfile(cardRadius: FactoryRadius.lg, rowHeight: 56, pagePadding: 16);
  static const platform = FactoryAppProfile(cardRadius: FactoryRadius.md, rowHeight: 40, pagePadding: 16);

  @override
  FactoryAppProfile copyWith({double? cardRadius, double? rowHeight, double? pagePadding}) => FactoryAppProfile(
        cardRadius: cardRadius ?? this.cardRadius,
        rowHeight: rowHeight ?? this.rowHeight,
        pagePadding: pagePadding ?? this.pagePadding,
      );

  @override
  FactoryAppProfile lerp(ThemeExtension<FactoryAppProfile>? other, double t) {
    if (other is! FactoryAppProfile) return this;
    return FactoryAppProfile(
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      rowHeight: rowHeight + (other.rowHeight - rowHeight) * t,
      pagePadding: pagePadding + (other.pagePadding - pagePadding) * t,
    );
  }
}

extension FactoryAppProfileContext on BuildContext {
  /// The app profile, or null when the app's theme sets none.
  FactoryAppProfile? get factoryProfileOrNull => Theme.of(this).extension<FactoryAppProfile>();
}

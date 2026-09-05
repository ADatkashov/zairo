import 'package:flutter/material.dart';

/// Factory's semantic color roles — the "stone" neutral + "pine" primary +
/// "gold" accent palette from the Factory Design System artifact. Dark mode
/// is its own tuned instance (brighter mint primary, warm near-black
/// background), not a computed inversion of light — see [FactoryColors.dark].
///
/// Exposed as a [ThemeExtension] so any widget can reach roles Flutter's
/// own [ColorScheme] doesn't have (surfaceAlt, primaryTint, accent) via
/// `Theme.of(context).extension<FactoryColors>()!`.
@immutable
class FactoryColors extends ThemeExtension<FactoryColors> {
  const FactoryColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryStrong,
    required this.primaryTint,
    required this.onPrimary,
    required this.accent,
    required this.accentTint,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.categoryCoral,
    required this.categoryCoralTint,
    required this.categoryLavender,
    required this.categoryLavenderTint,
    required this.categoryMint,
    required this.categoryMintTint,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryStrong;
  final Color primaryTint;
  final Color onPrimary;
  final Color accent;
  final Color accentTint;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Category-tag accents — Business Admin colors each vertical's icon
  /// chip with one of these (beauty→coral, auto→lavender, cleaning→mint)
  /// so a mixed list of businesses reads at a glance, the way the
  /// customer app's category icons already do. Not part of the semantic
  /// status roles above (success/warning/error/info stay reserved for
  /// state, not category identity).
  final Color categoryCoral;
  final Color categoryCoralTint;
  final Color categoryLavender;
  final Color categoryLavenderTint;
  final Color categoryMint;
  final Color categoryMintTint;

  static const light = FactoryColors(
    bg: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEDE8),
    border: Color(0xFFE1DED5),
    borderStrong: Color(0xFFC9C4B7),
    text: Color(0xFF1B1917),
    textSecondary: Color(0xFF5C564C),
    textTertiary: Color(0xFF7A7266),
    primary: Color(0xFF1B5C52),
    primaryStrong: Color(0xFF123F38),
    primaryTint: Color(0xFFDCEAE6),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC99A3E),
    accentTint: Color(0xFFE6CD97),
    success: Color(0xFF2E8B6F),
    // Darkened from the design system artifact's #B9862E (2.98:1 on `bg` —
    // fails WCAG AA even at the 3:1 large-text/UI-component floor). Same
    // hue/saturation, lower lightness: 4.64:1.
    warning: Color(0xFF906824),
    error: Color(0xFFB5453B),
    info: Color(0xFF3E6E93),
    categoryCoral: Color(0xFFFF6A54),
    categoryCoralTint: Color(0xFFFFE6E0),
    categoryLavender: Color(0xFF7B68F0),
    categoryLavenderTint: Color(0xFFEBE6FE),
    categoryMint: Color(0xFF17C99B),
    categoryMintTint: Color(0xFFDFF6EE),
  );

  static const dark = FactoryColors(
    bg: Color(0xFF0F0E0C),
    surface: Color(0xFF171613),
    surfaceAlt: Color(0xFF201E1A),
    border: Color(0xFF322F29),
    borderStrong: Color(0xFF423E37),
    text: Color(0xFFF2F0EA),
    textSecondary: Color(0xFFB5AFA3),
    textTertiary: Color(0xFF7A7266),
    primary: Color(0xFF4FCFB4),
    primaryStrong: Color(0xFF7CDFC9),
    primaryTint: Color(0xFF173029),
    onPrimary: Color(0xFF08211C),
    accent: Color(0xFFE0B563),
    accentTint: Color(0xFF3A2E17),
    success: Color(0xFF4FBE96),
    warning: Color(0xFFE0A94A),
    error: Color(0xFFE07A6E),
    info: Color(0xFF78A8CC),
    categoryCoral: Color(0xFFFF8A72),
    categoryCoralTint: Color(0xFF3A201C),
    categoryLavender: Color(0xFF9C8FFF),
    categoryLavenderTint: Color(0xFF2A2450),
    categoryMint: Color(0xFF3DE0B0),
    categoryMintTint: Color(0xFF163B30),
  );

  @override
  FactoryColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? primaryStrong,
    Color? primaryTint,
    Color? onPrimary,
    Color? accent,
    Color? accentTint,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? categoryCoral,
    Color? categoryCoralTint,
    Color? categoryLavender,
    Color? categoryLavenderTint,
    Color? categoryMint,
    Color? categoryMintTint,
  }) {
    return FactoryColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primaryTint: primaryTint ?? this.primaryTint,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      categoryCoral: categoryCoral ?? this.categoryCoral,
      categoryCoralTint: categoryCoralTint ?? this.categoryCoralTint,
      categoryLavender: categoryLavender ?? this.categoryLavender,
      categoryLavenderTint: categoryLavenderTint ?? this.categoryLavenderTint,
      categoryMint: categoryMint ?? this.categoryMint,
      categoryMintTint: categoryMintTint ?? this.categoryMintTint,
    );
  }

  @override
  FactoryColors lerp(ThemeExtension<FactoryColors>? other, double t) {
    if (other is! FactoryColors) return this;
    return FactoryColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      categoryCoral: Color.lerp(categoryCoral, other.categoryCoral, t)!,
      categoryCoralTint: Color.lerp(categoryCoralTint, other.categoryCoralTint, t)!,
      categoryLavender: Color.lerp(categoryLavender, other.categoryLavender, t)!,
      categoryLavenderTint: Color.lerp(categoryLavenderTint, other.categoryLavenderTint, t)!,
      categoryMint: Color.lerp(categoryMint, other.categoryMint, t)!,
      categoryMintTint: Color.lerp(categoryMintTint, other.categoryMintTint, t)!,
    );
  }
}

/// Convenience accessor: `context.factoryColors.primary`.
extension FactoryColorsContext on BuildContext {
  FactoryColors get factoryColors => Theme.of(this).extension<FactoryColors>()!;
}

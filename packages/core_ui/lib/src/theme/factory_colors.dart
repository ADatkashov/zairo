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
    required this.accentInk,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.coral,
    required this.coralTint,
    required this.lavender,
    required this.lavenderTint,
    required this.mint,
    required this.mintTint,
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

  /// Accent for *text* on light surfaces. [accent] gold is 2.4:1 on white and
  /// fails AA, so gold type (verified marks, loyalty labels) uses this instead.
  final Color accentInk;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Vertical/category accent colors — Customer App Redesign board
  /// (2026-09-05): bright chrome for category chips and status badges
  /// (Beauty/Auto/Cleaning), distinct from the muted `success`/`warning`/
  /// `error`/`info` semantic roles above, which stay reserved for actual
  /// state (confirmed/pending/failed), not category identity.
  final Color coral;
  final Color coralTint;
  final Color lavender;
  final Color lavenderTint;
  final Color mint;
  final Color mintTint;

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
    accentInk: Color(0xFF7A5612),
    // Darkened from #2E8B6F (4.2:1 on white) to clear AA 4.5:1.
    success: Color(0xFF1F7A4D),
    // Darkened from the design system artifact's #B9862E (2.98:1 on `bg` —
    // fails WCAG AA even at the 3:1 large-text/UI-component floor). Same
    // hue/saturation, lower lightness: 4.64:1.
    warning: Color(0xFF906824),
    error: Color(0xFFB3372E),
    info: Color(0xFF2F5FA8),
    coral: Color(0xFFFF6A54),
    coralTint: Color(0xFFFFE6E0),
    lavender: Color(0xFF7B68F0),
    lavenderTint: Color(0xFFEBE6FE),
    mint: Color(0xFF17C99B),
    mintTint: Color(0xFFDFF6EE),
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
    accentInk: Color(0xFFE0B563),
    success: Color(0xFF4FBE96),
    warning: Color(0xFFE0A94A),
    error: Color(0xFFE07A6E),
    info: Color(0xFF78A8CC),
    // Lifted lightness versus light-mode coral/lavender/mint, matching how
    // primary/accent are already brightened for dark — same hue family,
    // legible on the near-black `bg`.
    coral: Color(0xFFFF8770),
    coralTint: Color(0xFF3A231D),
    lavender: Color(0xFF9C8CF5),
    lavenderTint: Color(0xFF241F3D),
    mint: Color(0xFF2FE6B8),
    mintTint: Color(0xFF16352C),
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
    Color? accentInk,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? coral,
    Color? coralTint,
    Color? lavender,
    Color? lavenderTint,
    Color? mint,
    Color? mintTint,
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
      accentInk: accentInk ?? this.accentInk,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      coral: coral ?? this.coral,
      coralTint: coralTint ?? this.coralTint,
      lavender: lavender ?? this.lavender,
      lavenderTint: lavenderTint ?? this.lavenderTint,
      mint: mint ?? this.mint,
      mintTint: mintTint ?? this.mintTint,
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
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralTint: Color.lerp(coralTint, other.coralTint, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      lavenderTint: Color.lerp(lavenderTint, other.lavenderTint, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintTint: Color.lerp(mintTint, other.mintTint, t)!,
    );
  }
}

/// Convenience accessor: `context.factoryColors.primary`.
extension FactoryColorsContext on BuildContext {
  FactoryColors get factoryColors => Theme.of(this).extension<FactoryColors>()!;
}

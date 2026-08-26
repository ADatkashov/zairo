import 'package:flutter/material.dart';

/// Shadow scale from the Factory Design System artifact ("Elevation"
/// section). Factory shows rest state with a border, not a shadow —
/// [none] is the default for cards and inline rows. Reach for [sm] on a
/// hover/pressed micro-lift, [md] for a card that should read as raised
/// even at rest (provider/service cards), [lg] for anything that floats
/// above the page (sheets, dialogs, snackbars).
enum FactoryElevationLevel { none, sm, md, lg }

class FactoryElevation {
  const FactoryElevation._();

  static List<BoxShadow> resolve(FactoryElevationLevel level, Brightness brightness) {
    // The artifact's own shadow-rgb is pure black for dark mode — on a
    // near-black background (FactoryColors.dark.bg is 0x0F0E0C) a black
    // shadow at any of these alphas is functionally invisible, since
    // there's almost no luminance left to subtract. A light "glow" reads
    // instead: same alpha steps, warm near-white base (dark theme's own
    // `text` color) rather than black.
    final base = brightness == Brightness.light ? const Color(0xFF1B1917) : const Color(0xFFF2F0EA);
    switch (level) {
      case FactoryElevationLevel.none:
        return const [];
      case FactoryElevationLevel.sm:
        return [BoxShadow(color: base.withValues(alpha: 0.06), offset: const Offset(0, 1), blurRadius: 2)];
      case FactoryElevationLevel.md:
        return [
          BoxShadow(color: base.withValues(alpha: 0.06), offset: const Offset(0, 1), blurRadius: 2),
          BoxShadow(color: base.withValues(alpha: 0.04), offset: const Offset(0, 1), blurRadius: 1),
        ];
      case FactoryElevationLevel.lg:
        return [
          BoxShadow(color: base.withValues(alpha: 0.14), offset: const Offset(0, 8), blurRadius: 24),
          BoxShadow(color: base.withValues(alpha: 0.08), offset: const Offset(0, 2), blurRadius: 6),
        ];
    }
  }
}

/// Convenience accessor: `context.factoryElevation(FactoryElevationLevel.md)`.
extension FactoryElevationContext on BuildContext {
  List<BoxShadow> factoryElevation(FactoryElevationLevel level) =>
      FactoryElevation.resolve(level, Theme.of(this).brightness);
}

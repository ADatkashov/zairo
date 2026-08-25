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
    final base = brightness == Brightness.light ? const Color(0xFF1B1917) : Colors.black;
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

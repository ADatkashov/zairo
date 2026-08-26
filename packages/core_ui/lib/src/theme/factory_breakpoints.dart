import 'package:flutter/widgets.dart';

/// Width tiers from the Factory Design System artifact's "Responsive
/// behavior" section: mobile is the primary target for the customer app,
/// tablet and desktop are the defined (not improvised) answers for wider
/// surfaces — desktop in particular is what Business/Platform Admin targets.
enum FactoryScreenSize { mobile, tablet, desktop }

class FactoryBreakpoints {
  const FactoryBreakpoints._();

  /// Below this width: [FactoryScreenSize.mobile].
  static const double tablet = 768;

  /// At or above this width: [FactoryScreenSize.desktop].
  static const double desktop = 1200;

  static FactoryScreenSize resolve(double width) {
    if (width >= desktop) return FactoryScreenSize.desktop;
    if (width >= tablet) return FactoryScreenSize.tablet;
    return FactoryScreenSize.mobile;
  }

  static FactoryScreenSize of(BuildContext context) => resolve(MediaQuery.sizeOf(context).width);
}

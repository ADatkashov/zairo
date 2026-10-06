import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';

/// "▲ +12%" change chip for metrics. [delta] is a signed number; the arrow
/// and color follow its sign, and the arrow keeps the meaning readable
/// without color. Set [positiveIsGood] to false for metrics where a rise is
/// bad (refund rate), which flips the colors but not the arrow.
class FactoryTrendBadge extends StatelessWidget {
  const FactoryTrendBadge({
    super.key,
    required this.delta,
    this.suffix = '%',
    this.fractionDigits = 0,
    this.positiveIsGood = true,
    this.onDark = false,
  });

  final num delta;
  final String suffix;
  final int fractionDigits;
  final bool positiveIsGood;

  /// Draws on a dark hero card: translucent white fill, light text.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final up = delta > 0;
    final flat = delta == 0;
    final good = flat || (up == positiveIsGood);
    final tone = flat ? colors.textSecondary : (good ? colors.success : colors.error);
    final bg = onDark ? Colors.white.withValues(alpha: 0.16) : Color.alphaBlend(tone.withValues(alpha: 0.14), colors.surface);
    final fg = onDark ? Colors.white : tone;
    final sign = up ? '+' : (flat ? '' : '−');
    final text = '${flat ? '–' : (up ? '▲' : '▼')} $sign${delta.abs().toStringAsFixed(fractionDigits)}$suffix';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 3),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(text, style: FactoryTypography.mono(size: 12, color: fg)),
    );
  }
}

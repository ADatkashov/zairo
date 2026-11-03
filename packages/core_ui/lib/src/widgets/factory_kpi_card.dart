import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';
import 'factory_card.dart';
import 'factory_sparkline.dart';
import 'factory_trend_badge.dart';

/// A dashboard metric card: label, a big tabular value, and — when the data
/// exists — a change chip ([delta]) and a trend line ([trend]). Both are
/// optional so the same card serves metrics that only have a current value
/// (most of the platform dashboard) and ones with history (revenue over time).
///
/// [icon] sits in a tinted chip at the card's top-right corner, painted in
/// [accent] (the primary hue by default) — the same accent colours the trend
/// line, so a row of cards reads as a set of distinct metrics. [caption] is the
/// small print under the figure ("vs prior 7 days", "2 visits today").
///
/// [warn] paints the value in the error hue for counts that mean "someone
/// needs to act" (failed refunds, pending approvals).
class FactoryKpiCard extends StatelessWidget {
  const FactoryKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.caption,
    this.delta,
    this.deltaSuffix = '%',
    this.positiveIsGood = true,
    this.trend,
    this.trendLabel,
    this.warn = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Hue of the icon chip and the trend line; null takes the primary colour.
  final Color? accent;

  /// Small print next to the change chip, or under the figure when there is no
  /// chip.
  final String? caption;

  /// Signed change versus the previous period; null hides the chip.
  final num? delta;
  final String deltaSuffix;

  /// False for metrics where a rise is bad (refund rate).
  final bool positiveIsGood;

  /// Recent values, oldest first. Fewer than two points draws nothing, so the
  /// sparkline is skipped entirely instead of leaving an empty gap.
  final List<double>? trend;

  /// Screen-reader description of [trend] (the line itself has no text).
  final String? trendLabel;

  final bool warn;

  /// Makes the whole card a link to the list behind the number (null = plain card).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final trend = this.trend;
    final delta = this.delta;
    final caption = this.caption;
    final hue = accent ?? colors.primary;
    return FactoryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: FactorySpacing.space2),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(hue.withValues(alpha: 0.12), colors.surface),
                    borderRadius: FactoryRadius.smRadius,
                  ),
                  child: Icon(icon, size: 16, color: hue),
                ),
              ],
            ],
          ),
          const SizedBox(height: FactorySpacing.space1),
          // Scales down instead of overflowing: a long amount in a narrow card
          // (320 px phone, large system font) shrinks rather than clips.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              // Figures are data: mono + tabular so a row of cards lines up.
              style: FactoryTypography.mono(size: 22, weight: FontWeight.w600, color: warn ? colors.error : colors.text),
            ),
          ),
          if (delta != null || caption != null) ...[
            const SizedBox(height: FactorySpacing.space1),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (delta != null) FactoryTrendBadge(delta: delta, suffix: deltaSuffix, positiveIsGood: positiveIsGood),
                if (caption != null) Text(caption, style: textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ],
          if (trend != null && trend.length >= 2) ...[
            const SizedBox(height: FactorySpacing.space2),
            FactorySparkline(values: trend, color: hue, semanticLabel: trendLabel),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
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
/// [warn] paints the value in the error hue for counts that mean "someone
/// needs to act" (failed refunds, pending approvals).
class FactoryKpiCard extends StatelessWidget {
  const FactoryKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.delta,
    this.deltaSuffix = '%',
    this.positiveIsGood = true,
    this.trend,
    this.trendLabel,
    this.warn = false,
  });

  final String label;
  final String value;
  final IconData? icon;

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

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final trend = this.trend;
    final delta = this.delta;
    return FactoryCard(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colors.primary),
                const SizedBox(width: FactorySpacing.space2),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space1),
          Text(
            value,
            // Figures are data: mono + tabular so a row of cards lines up.
            style: FactoryTypography.mono(size: 22, weight: FontWeight.w600, color: warn ? colors.error : colors.text),
          ),
          if (delta != null) ...[
            const SizedBox(height: FactorySpacing.space1),
            FactoryTrendBadge(delta: delta, suffix: deltaSuffix, positiveIsGood: positiveIsGood),
          ],
          if (trend != null && trend.length >= 2) ...[
            const SizedBox(height: FactorySpacing.space2),
            FactorySparkline(values: trend, semanticLabel: trendLabel),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';

/// One row of a [FactoryShareList]: a name, its figure, and what fraction of the
/// whole it is ([share], 0–1).
class FactoryShareItem {
  const FactoryShareItem({
    required this.label,
    required this.valueLabel,
    required this.share,
    this.caption,
    this.leading,
    this.color,
    this.onTap,
  });

  final String label;

  /// The already-formatted figure (money, a count).
  final String valueLabel;

  /// Fraction of the whole, clamped to 0–1 when drawn.
  final double share;

  /// A second line under [label] ("Strategic consulting"), or null.
  final String? caption;

  /// Avatar or icon before the label, or null.
  final Widget? leading;

  /// The bar's colour; null takes the primary hue.
  final Color? color;
  final VoidCallback? onTap;
}

/// A ranked list where every row says how big a part of the total it is: label
/// and figure on top, a proportional bar and the percentage below. The "Top
/// customers" / "Top services" block of a dashboard — the bar makes the ranking
/// readable at a glance, the figures make it exact.
class FactoryShareList extends StatelessWidget {
  const FactoryShareList({super.key, required this.items});

  final List<FactoryShareItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final item in items) _ShareRow(item: item)],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.item});

  final FactoryShareItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final share = item.share.clamp(0.0, 1.0);
    // One decimal ("27.2%"), none for a whole number ("60%").
    final tenths = (share * 1000).round() / 10;
    final percent = '${tenths == tenths.roundToDouble() ? tenths.toStringAsFixed(0) : tenths.toStringAsFixed(1)}%';

    // With a large system font the figure no longer fits beside the name on a phone; it goes under it.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (item.caption != null)
          Text(
            item.caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
      ],
    );
    final figure = Text(
      item.valueLabel,
      style: FactoryTypography.mono(size: 13, weight: FontWeight.w600, color: colors.text),
    );

    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.leading != null) ...[item.leading!, const SizedBox(width: FactorySpacing.space3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stacked)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, figure])
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: name), const SizedBox(width: FactorySpacing.space2), figure],
                  ),
                const SizedBox(height: FactorySpacing.space2),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: colors.surfaceAlt),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: share,
                                child: ColoredBox(color: item.color ?? colors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space2),
                    SizedBox(
                      width: 44,
                      child: Text(
                        percent,
                        textAlign: TextAlign.end,
                        style: FactoryTypography.mono(size: 12, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return item.onTap == null ? body : InkWell(onTap: item.onTap, child: body);
  }
}

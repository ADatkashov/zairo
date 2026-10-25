import 'package:flutter/material.dart';

import '../theme/factory_app_profile.dart';
import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';

/// One line of a [FactoryAlertPanel]: what needs doing, with the number that
/// says how much. The whole row is the tap target — [actionLabel] is only the
/// hint at its end ("Review"), not a second button to find.
class FactoryAlertItem {
  const FactoryAlertItem({required this.label, required this.onTap, this.icon, this.value, this.actionLabel});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// A figure shown at the row's end ("$870"); null leaves it out.
  final String? value;
  final String? actionLabel;
}

/// The "needs attention" panel of a dashboard: a red-tinted card that lists
/// everything waiting on a person, most urgent first, each row one tap from the
/// place where it is dealt with. [count] is the pill beside the title; leave it
/// null to hide the pill.
///
/// With nothing to do, show [FactoryAlertPanel.allClear] instead — a calm one-line
/// confirmation, so the absence of a warning is itself visible.
class FactoryAlertPanel extends StatelessWidget {
  const FactoryAlertPanel({super.key, required this.title, required this.items, this.count}) : _allClear = false;

  /// The calm state: a green check and [title], no rows.
  const FactoryAlertPanel.allClear({super.key, required this.title}) : items = const [], count = null, _allClear = true;

  final String title;
  final List<FactoryAlertItem> items;
  final int? count;
  final bool _allClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.lgRadius;
    final tone = _allClear ? colors.success : colors.error;

    final header = Row(
      children: [
        Icon(_allClear ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, size: 20, color: tone),
        const SizedBox(width: FactorySpacing.space2),
        Expanded(
          child: Text(
            title,
            style: textTheme.titleSmall?.copyWith(color: _allClear ? colors.text : tone, fontWeight: FontWeight.w700),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: FactorySpacing.space2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: 2),
            decoration: ShapeDecoration(color: tone, shape: const StadiumBorder()),
            child: Text('$count', style: FactoryTypography.mono(size: 12, weight: FontWeight.w600, color: colors.surface)),
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: 0.06), colors.surface),
        borderRadius: radius,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space3,
                FactorySpacing.space4,
                _allClear ? FactorySpacing.space3 : FactorySpacing.space1,
              ),
              child: header,
            ),
            for (final item in items) _Row(item: item, tone: tone),
            if (items.isNotEmpty) const SizedBox(height: FactorySpacing.space1),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.tone});

  final FactoryAlertItem item;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final action = item.actionLabel;
    // With a large system font the figure and the hint no longer fit beside the
    // label on a phone; they drop to a second line under it instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
    final figure = item.value == null
        ? null
        : Text(item.value!, style: FactoryTypography.mono(size: 13, weight: FontWeight.w600, color: tone));
    final hint = action == null
        ? null
        : Text(action, style: textTheme.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w600));
    final label = Text(item.label, style: textTheme.bodyMedium);
    return InkWell(
      onTap: item.onTap,
      child: ConstrainedBox(
        // A comfortable touch target even for a one-line row.
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 18, color: colors.textSecondary),
                const SizedBox(width: FactorySpacing.space3),
              ],
              Expanded(
                child: stacked && (figure != null || hint != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label,
                          const SizedBox(height: 2),
                          Wrap(spacing: FactorySpacing.space2, children: [?figure, ?hint]),
                        ],
                      )
                    : label,
              ),
              if (!stacked) ...[
                if (figure != null) ...[const SizedBox(width: FactorySpacing.space2), figure],
                if (hint != null) ...[const SizedBox(width: FactorySpacing.space2), hint],
              ],
              const SizedBox(width: FactorySpacing.space1),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

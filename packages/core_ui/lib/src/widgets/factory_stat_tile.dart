import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';

/// One cell of a profile/dashboard stat row — a big value over a label
/// ("12" / "Bookings"), the pattern the reference mockups used for
/// at-a-glance counts. Meant to sit side by side with siblings inside a
/// [FactoryCard] or a plain [Row], not to be a card itself.
class FactoryStatTile extends StatelessWidget {
  const FactoryStatTile({super.key, required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: FactorySpacing.space1),
        ],
        Text(value, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
      ],
    );
  }
}

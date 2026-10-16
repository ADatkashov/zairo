import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';
import 'factory_card.dart';

/// A titled card that groups report filters, with a "Reset" action once any
/// filter is changed ([onReset] null hides it). Lay it out as a side column on
/// wide screens and stack it on top on narrow ones — it only draws the card.
class FactoryFilterPanel extends StatelessWidget {
  const FactoryFilterPanel({super.key, required this.title, required this.children, this.resetLabel, this.onReset});

  final String title;
  final List<Widget> children;
  final String? resetLabel;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.titleSmall)),
              if (onReset != null && resetLabel != null) TextButton(onPressed: onReset, child: Text(resetLabel!)),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: FactorySpacing.space3), child],
        ],
      ),
    );
  }
}

/// A small caption above one filter control inside a [FactoryFilterPanel].
class FactoryFilterField extends StatelessWidget {
  const FactoryFilterField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
        const SizedBox(height: FactorySpacing.space2),
        child,
      ],
    );
  }
}

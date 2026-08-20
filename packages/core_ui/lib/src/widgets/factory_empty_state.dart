import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';

/// "No available times today. Try another date." — an empty state always
/// pairs a plain-language explanation with a way forward, per the design
/// system's rule against tutorials/tooltips standing in for a clear
/// default. [onAction] is optional: some empty states (Favorites with
/// nothing saved yet) have nothing useful to offer beyond the explanation.
class FactoryEmptyState extends StatelessWidget {
  const FactoryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space8, horizontal: FactorySpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: colors.surfaceAlt, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: colors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(title, style: textTheme.titleSmall?.copyWith(color: colors.text), textAlign: TextAlign.center),
          const SizedBox(height: FactorySpacing.space1),
          Text(message, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: FactorySpacing.space4),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

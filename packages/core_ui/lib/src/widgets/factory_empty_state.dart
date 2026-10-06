import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_motion.dart';
import '../theme/factory_spacing.dart';
import 'factory_button.dart';

/// "No available times today. Try another date." — an empty state always
/// pairs a plain-language explanation with a way forward, per the design
/// system's rule against tutorials/tooltips standing in for a clear
/// default. [onAction] is optional: some empty states (Favorites with
/// nothing saved yet) have nothing useful to offer beyond the explanation.
///
/// The icon sits in a soft glowing tile, and the whole block eases in
/// (a short fade and rise) unless the platform asks for reduced motion.
/// [compact] is the smaller treatment for empty states inside a card or a
/// list section rather than a whole screen.
class FactoryEmptyState extends StatelessWidget {
  const FactoryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final tile = compact ? 64.0 : 96.0;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? FactorySpacing.space6 : FactorySpacing.space10,
        horizontal: FactorySpacing.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: colors.primaryTint,
              borderRadius: BorderRadius.circular(tile * 0.3),
              // Ambient glow: a soft halo of the brand color, not a shadow.
              boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.18), blurRadius: 32, spreadRadius: 2)],
            ),
            child: Icon(icon, size: tile * 0.42, color: colors.primary),
          ),
          SizedBox(height: compact ? FactorySpacing.space4 : FactorySpacing.space6),
          Text(
            title,
            style: (compact ? textTheme.titleSmall : textTheme.titleMedium)?.copyWith(color: colors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FactorySpacing.space2),
          if (message.isNotEmpty)
            Text(message, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: FactorySpacing.space5),
            FactoryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FactoryMotion.resolve(context, FactoryMotion.slow),
      curve: FactoryMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: content,
    );
  }
}

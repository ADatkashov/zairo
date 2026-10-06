import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_motion.dart';
import '../theme/factory_spacing.dart';
import 'factory_button.dart';

/// A human-readable message plus a retry action — never a raw exception.
/// [message] is the caller's job to make plain-language before it reaches
/// here; this widget just gives it a consistent, calm presentation instead
/// of a stack trace on screen. Eases in like [FactoryEmptyState] and
/// respects reduced motion.
class FactoryErrorState extends StatelessWidget {
  const FactoryErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space8, horizontal: FactorySpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Color.alphaBlend(colors.error.withValues(alpha: 0.12), colors.surface),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Symbols.error_outline_rounded, size: 32, color: colors.error),
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FactorySpacing.space5),
          FactoryButton(label: retryLabel, variant: FactoryButtonVariant.secondary, onPressed: onRetry),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: FactoryMotion.resolve(context, FactoryMotion.base),
      curve: FactoryMotion.standard,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: content,
    );
  }
}

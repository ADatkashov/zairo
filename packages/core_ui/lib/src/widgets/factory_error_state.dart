import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';

/// A human-readable message plus a retry action — never a raw exception.
/// [message] is the caller's job to make plain-language before it reaches
/// here; this widget just gives it a consistent, calm presentation instead
/// of a stack trace on screen.
class FactoryErrorState extends StatelessWidget {
  const FactoryErrorState({super.key, required this.message, required this.onRetry, this.retryLabel = 'Try again'});

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6, horizontal: FactorySpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color.alphaBlend(colors.error.withValues(alpha: 0.12), colors.surface),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded, size: 20, color: colors.error),
          ),
          const SizedBox(height: FactorySpacing.space3),
          Text(message, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: FactorySpacing.space4),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

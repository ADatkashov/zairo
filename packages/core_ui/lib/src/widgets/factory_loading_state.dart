import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';

/// The full-section loading placeholder for data that isn't shaped enough
/// yet to skeleton (see [FactorySkeleton] for content that is). Centers
/// itself — callers drop this directly where the data would otherwise go.
class FactoryLoadingState extends StatelessWidget {
  const FactoryLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
          if (message != null) ...[
            const SizedBox(height: FactorySpacing.space4),
            Text(message!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import 'factory_skeleton.dart';

/// What a list of cards looks like while it loads: [itemCount] card-shaped rows (a picture block and two text lines)
/// instead of a lone spinner. The page keeps its shape, so nothing jumps when the real rows arrive, and it reads as
/// "loading" faster than a spinner does. Not scrollable and not interactive; hidden from screen readers (the
/// content that replaces it is what they should hear).
class FactoryListSkeleton extends StatelessWidget {
  const FactoryListSkeleton({super.key, this.itemCount = 5, this.padding = const EdgeInsets.all(FactorySpacing.space4)});

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return ExcludeSemantics(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
        itemBuilder: (context, _) => Container(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: FactoryRadius.mdRadius,
          ),
          child: const Row(
            children: [
              FactorySkeleton(width: 56, height: 56, borderRadius: FactoryRadius.smRadius),
              SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Line(widthFactor: 0.7, height: 14),
                    SizedBox(height: FactorySpacing.space2),
                    _Line(widthFactor: 0.45, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: FactorySkeleton(width: double.infinity, height: height),
  );
}

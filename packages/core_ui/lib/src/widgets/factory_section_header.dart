import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// A row heading for a horizontally-scrolling rail or a list section —
/// "Popular categories · See all", "Top services · See all". At most one of
/// [actionLabel]/[trailing] should be set; [trailing] wins if both are.
class FactorySectionHeader extends StatelessWidget {
  const FactorySectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(color: colors.text, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          trailing!
        else if (actionLabel != null && onActionTap != null)
          TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}

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

    final trailingWidget = trailing ??
        (actionLabel != null && onActionTap != null
            ? TextButton(onPressed: onActionTap, child: Text(actionLabel!))
            : null);

    // Title left, action right. When both don't fit on one line (a phone, large text) the action
    // moves under the title instead of squeezing it or overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(color: colors.text, fontWeight: FontWeight.w700),
              ),
            ),
            if (trailingWidget != null)
              ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: trailingWidget),
          ],
        );
      },
    );
  }
}

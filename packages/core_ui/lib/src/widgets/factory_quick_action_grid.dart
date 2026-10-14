import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_icon_size.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';
import 'factory_badge.dart';

/// One tile of a [FactoryQuickActionGrid].
@immutable
class FactoryQuickAction {
  const FactoryQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// A short flag ("NEW") pinned to the icon's top-right corner. Already
  /// localized by the caller; null shows none.
  final String? badge;
}

/// A tab-bar-sized launcher: a fixed number of columns of icon-over-label
/// tiles (4×2 on Home), the Astana Hub home-screen pattern. Unlike
/// [FactoryCategoryTile] (a filter that toggles selection) every tile here is
/// a plain shortcut into another screen.
///
/// Rows are built from [Row]s rather than a `GridView`, so a tile grows with
/// the user's text scale instead of clipping its label to a fixed cell height.
class FactoryQuickActionGrid extends StatelessWidget {
  const FactoryQuickActionGrid({
    super.key,
    required this.actions,
    this.columns = 4,
  }) : assert(columns > 0);

  final List<FactoryQuickAction> actions;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < actions.length; start += columns) {
      final end = start + columns < actions.length ? start + columns : actions.length;
      final slice = actions.sublist(start, end);
      if (rows.isNotEmpty) rows.add(const SizedBox(height: FactorySpacing.space3));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final action in slice) Expanded(child: _QuickActionTile(action: action)),
            // Keep a short last row aligned to the same column grid.
            for (var i = slice.length; i < columns; i++) const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final FactoryQuickAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final badge = action.badge;
    return Semantics(
      button: true,
      label: badge == null ? action.label : '${action.label}, $badge',
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: FactoryRadius.lgRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(action.icon, size: FactoryIconSize.lg, color: colors.primary),
                    if (badge != null)
                      Positioned(
                        top: -6,
                        right: -14,
                        child: FactoryBadge(
                          label: badge,
                          backgroundColor: colors.error,
                          foregroundColor: colors.bg,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: FactorySpacing.space1),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0,
                  height: 1.2,
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

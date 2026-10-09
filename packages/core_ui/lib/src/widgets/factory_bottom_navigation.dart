import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_elevation.dart';
import '../theme/factory_motion.dart';

/// One tab of a [FactoryBottomNavigation] bar. A single [icon] rather than
/// a separate selected/unselected pair — the Customer App Redesign board's
/// own `BottomNav.dc.html` renders one Material Symbols glyph per tab and
/// toggles solid-vs-outline via `font-variation-settings: 'FILL' <0|1>`
/// keyed off `isActive`, not two different icon glyphs ([_NavItem] applies
/// that same fill toggle below).
class FactoryNavDestination {
  const FactoryNavDestination({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// A small count on the icon (new messages, say); nothing is drawn at 0.
  /// Shown as "9+" from ten up.
  final int badgeCount;
}

/// The customer app's tab bar — never more than four or five destinations
/// (the design system's own rule: every additional tab is tested against
/// "does this replace a search," and cut if not).
///
/// Renders as a floating, rounded pill bar (Customer App Redesign board,
/// 2026-09-05) rather than an edge-to-edge Material [NavigationBar] — the
/// active tab gets a `primaryTint` capsule instead of the bar's own
/// indicator. Kept as a bespoke `Row`/`InkWell` layout instead of
/// `NavigationBar` + `NavigationBarThemeData` because that API has no way to
/// inset the bar itself from the screen edges or round all four corners.
/// Public API (`destinations`/`selectedIndex`/`onDestinationSelected`) is
/// unchanged from the previous `NavigationBar`-backed version, so call sites
/// (`MainWrapper`) didn't need to change.
class FactoryBottomNavigation extends StatelessWidget {
  const FactoryBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<FactoryNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: context.factoryElevation(FactoryElevationLevel.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Flexible (loose): with four short labels every item keeps its
            // natural width exactly as before; with five or longer labels the
            // items shrink and the label ellipsizes instead of overflowing.
            for (var i = 0; i < destinations.length; i++)
              Flexible(
                child: _NavItem(
                  // Five or more tabs share ~70px each on a phone; the roomy
                  // 12px side padding left a long label ("Бизнестер") ~50px
                  // and it ellipsized to "Бизне…".
                  dense: destinations.length > 4,
                  destination: destinations[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dense,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final bool dense;
  final FactoryNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final color = isSelected ? colors.primary : colors.textTertiary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.badgeCount > 0
          ? '${destination.label}, ${destination.badgeCount}'
          : destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: FactoryMotion.fast,
            curve: FactoryMotion.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryTint : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        destination.icon,
                        fill: isSelected ? 1 : 0,
                        size: 22,
                        color: color,
                      ),
                      if (destination.badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: -9,
                          child: _CountBadge(count: destination.badgeCount),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 10, letterSpacing: 0, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // error (not coral) so the count keeps AA contrast with onError text.
        color: colors.error,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

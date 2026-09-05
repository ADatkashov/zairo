import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_elevation.dart';
import '../theme/factory_motion.dart';

/// One tab of a [FactoryBottomNavigation] bar.
class FactoryNavDestination {
  const FactoryNavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
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
            for (var i = 0; i < destinations.length; i++)
              _NavItem(
                destination: destinations[i],
                isSelected: i == selectedIndex,
                onTap: () => onDestinationSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.isSelected, required this.onTap});

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
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: FactoryMotion.fast,
            curve: FactoryMotion.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryTint : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isSelected ? destination.selectedIcon : destination.icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: color),
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

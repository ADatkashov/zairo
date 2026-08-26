import 'package:flutter/material.dart';

/// One tab of a [FactoryBottomNavigation] bar.
class FactoryNavDestination {
  const FactoryNavDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The customer app's tab bar — five destinations, never more (the design
/// system's own rule: every additional tab is tested against "does this
/// replace a search," and cut if not). Wraps [NavigationBar], which already
/// picks up `factory_theme.dart`'s `navigationBarTheme`; this just gives the
/// call site a named, destination-model API instead of building
/// `NavigationDestination` lists inline.
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
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

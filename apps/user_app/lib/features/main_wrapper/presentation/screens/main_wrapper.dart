import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';

class MainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: FactoryBottomNavigation(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        // Icon names match BottomNav.dc.html's own `icon` field verbatim
        // (home/search/calendar_month/person) — "Записи" uses calendar_month
        // in the design board, not event_note.
        destinations: [
          FactoryNavDestination(
            icon: Symbols.home_rounded,
            label: l10n.navHome,
          ),
          FactoryNavDestination(
            icon: Symbols.search_rounded,
            label: l10n.navSearch,
          ),
          FactoryNavDestination(
            icon: Symbols.calendar_month_rounded,
            label: l10n.navBookings,
          ),
          FactoryNavDestination(
            icon: Symbols.person_rounded,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/widgets/change_avatar_dialog.dart';
import '../features/automation/presentation/screens/automation_center_screen.dart';
import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/campaigns/presentation/screens/campaign_center_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/loyalty/presentation/screens/loyalty_screen.dart';
import '../features/messaging/presentation/screens/business_inbox_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../l10n/app_localizations.dart';

/// The desktop answer to this app's mobile linear push-navigation
/// (see AuthGate's comment on why there's no router/shell there) — the
/// design system's Responsive Navigation row calls for a sidebar on
/// Business/Platform Admin at desktop width, so this only renders at
/// [FactoryScreenSize.desktop]; below that, [ResponsiveOwnerHome] falls
/// straight through to [DashboardScreen] unchanged, same as before this
/// existed.
///
/// Each destination keeps its own Scaffold/AppBar exactly as it already
/// does when reached by push on mobile — this composes them side-by-side
/// rather than stripping their chrome, so nothing about DashboardScreen,
/// BillingScreen or SettingsScreen had to change to gain a desktop shell.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    // AdminShell only ever renders once logged in (see ResponsiveOwnerHome,
    // reached through AuthGate) -- a null id here would mean a logout
    // happened mid-frame, same edge case DashboardScreen already handles.
    final ownerUserId = ref.watch(authControllerProvider).value?.id;

    final destinations = [
      AdminSidebarDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: l10n.navDashboard),
      AdminSidebarDestination(
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign_rounded,
        label: l10n.campaignCenterNavLabel,
      ),
      AdminSidebarDestination(
        icon: Icons.bolt_outlined,
        selectedIcon: Icons.bolt,
        label: l10n.automationCenterNavLabel,
      ),
      AdminSidebarDestination(
        icon: Icons.loyalty_outlined,
        selectedIcon: Icons.loyalty,
        label: l10n.loyaltyNavLabel,
      ),
      AdminSidebarDestination(
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        label: l10n.messagingNavLabel,
      ),
      AdminSidebarDestination(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: l10n.billingScreenTitle,
      ),
      AdminSidebarDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: l10n.settingsButtonTooltip),
    ];

    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            destinations: destinations,
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
          ),
          VerticalDivider(width: 1, color: colors.border),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const DashboardScreen(),
                if (ownerUserId != null) CampaignCenterScreen(ownerUserId: ownerUserId) else const SizedBox.shrink(),
                if (ownerUserId != null)
                  AutomationCenterScreen(ownerUserId: ownerUserId)
                else
                  const SizedBox.shrink(),
                if (ownerUserId != null) LoyaltyScreen(ownerUserId: ownerUserId) else const SizedBox.shrink(),
                if (ownerUserId != null)
                  BusinessInboxScreen(ownerUserId: ownerUserId)
                else
                  const SizedBox.shrink(),
                const BillingScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSidebarDestination {
  const AdminSidebarDestination({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The branded 220px-wide sidebar: the Factory wordmark, the nav list with
/// a rounded active pill (the same visual language as the redesigned
/// customer app, carried into the owner's tool — see the Business Admin
/// artifact), and a footer identifying who's signed in. Kept as its own
/// widget (rather than inlined into [AdminShell]) so it stays a pure
/// presentation component, easy to find in the widget tree from tests.
class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key, required this.destinations, required this.selectedIndex, required this.onSelect});

  final List<AdminSidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).value;

    return Container(
      width: 220,
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, FactorySpacing.space5),
            child: Row(
              children: [
                const FactoryLogomark(size: 26),
                const SizedBox(width: FactorySpacing.space2),
                Text(
                  'Factory',
                  style: textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: colors.text),
                ),
              ],
            ),
          ),
          for (var i = 0; i < destinations.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _SidebarNavItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ],
          const Spacer(),
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: FactorySpacing.space2),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: user.avatarUrl != null),
                    child: FactoryAvatar(
                      initials: _initialsFor(user.displayName),
                      size: 34,
                      image: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge,
                        ),
                        Text(l10n.ownerRoleLabel, style: textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({required this.destination, required this.selected, required this.onTap});

  final AdminSidebarDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? colors.primary : colors.textSecondary;

    return Material(
      color: selected ? colors.primaryTint : Colors.transparent,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.mdRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: 11),
          child: Row(
            children: [
              Icon(selected ? destination.selectedIcon : destination.icon, size: 20, color: color),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Picks [AdminShell] at desktop width, [DashboardScreen] below it —
/// the single place that branches on [FactoryBreakpoints], so AuthGate
/// itself stays a plain role switch.
class ResponsiveOwnerHome extends StatelessWidget {
  const ResponsiveOwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FactoryBreakpoints.of(context) == FactoryScreenSize.desktop
        ? const AdminShell()
        : const DashboardScreen();
  }
}

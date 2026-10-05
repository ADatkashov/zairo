import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/widgets/change_avatar_dialog.dart';
import '../l10n/app_localizations.dart';

class AdminSidebarDestination {
  const AdminSidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// A count on the item (new messages); nothing is drawn at 0.
  final int badgeCount;
}

/// The branded 220px-wide sidebar (72px icon-only rail when [compact], used at
/// tablet width): the Factory wordmark, the nav list with
/// a rounded active pill (the same visual language as the redesigned
/// customer app, carried into the owner's tool — see the Business Admin
/// artifact), and a footer identifying who's signed in. Kept as its own
/// widget (rather than inlined into [AdminShell]) so it stays a pure
/// presentation component, easy to find in the widget tree from tests.
class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.compact = false,
  });

  final List<AdminSidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Icons only (labels become tooltips) — the rail shown at tablet width.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).value;

    return Container(
      width: compact ? 72 : 220,
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FactorySpacing.space2 : FactorySpacing.space3,
        vertical: FactorySpacing.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, FactorySpacing.space5),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const FactoryLogomark(size: 26),
                if (!compact) ...[
                  const SizedBox(width: FactorySpacing.space2),
                  Text(
                    'Factory',
                    style: textTheme.headlineSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: colors.text),
                  ),
                ],
              ],
            ),
          ),
          for (var i = 0; i < destinations.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _SidebarNavItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              compact: compact,
              onTap: () => onSelect(i),
            ),
          ],
          const Spacer(),
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: FactorySpacing.space2),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: user.avatarUrl != null),
                    child: FactoryAvatar(
                      initials: _initialsFor(user.displayName),
                      size: 34,
                      image: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    ),
                  ),
                  if (!compact) ...[
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final AdminSidebarDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? colors.primary : colors.textSecondary;

    final item = Material(
      color: selected ? colors.primaryTint : Colors.transparent,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.mdRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : FactorySpacing.space3, vertical: 11),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Badge(
                isLabelVisible: destination.badgeCount > 0,
                label: Text(destination.badgeCount > 9 ? '9+' : '${destination.badgeCount}'),
                backgroundColor: colors.coral,
                child: Icon(selected ? destination.selectedIcon : destination.icon, size: 20, color: color),
              ),
              if (!compact) ...[
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
            ],
          ),
        ),
      ),
    );
    // The rail has no room for labels: they become the tooltip.
    return compact ? Tooltip(message: destination.label, child: item) : item;
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

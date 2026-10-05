import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/notifications_providers.dart';

/// A bell button with an unread-count badge (Customer App Redesign board,
/// 2026-09-05) — pushes [NotificationsScreen] rather than something inline,
/// same reasoning as Profile's favorites stat tile pushing [FavoritesScreen].
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final userId = ref.watch(authControllerProvider).value?.id;
    final unreadCount = userId == null
        ? 0
        : ref.watch(unreadNotificationsCountProvider(userId)).value ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: FactoryRadius.lgRadius,
            border: Border.all(color: colors.border),
          ),
          child: IconButton(
            icon: Icon(Symbols.notifications_rounded, color: colors.text),
            tooltip: l10n.notificationBellTooltip,
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../data/models/app_notification.dart';
import '../providers/notifications_providers.dart';

/// Pushed from Home's bell icon — resolves the current user itself via
/// [authControllerProvider] rather than taking a userId constructor param,
/// same reasoning as FavoritesScreen (also not its own bottom-nav tab).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.notificationsTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(
                icon: Icons.notifications_none_rounded,
                message: l10n.notificationsLoggedOutPrompt,
              )
            : _NotificationsList(userId: user.id),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  final String userId;

  const _NotificationsList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(myNotificationsProvider(userId));

    return notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: FactoryEmptyState(
              icon: Icons.notifications_none_rounded,
              title: l10n.notificationsEmptyTitle,
              message: l10n.notificationsEmptyMessage,
            ),
          );
        }
        final hasUnread = notifications.any((n) => !n.read);
        return Column(
          children: [
            if (hasUnread)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FactorySpacing.space4,
                    vertical: FactorySpacing.space2,
                  ),
                  child: FactoryButton(
                    label: l10n.notificationsMarkAllReadButton,
                    variant: FactoryButtonVariant.text,
                    onPressed: () async {
                      await ref
                          .read(notificationsApiProvider)
                          .markAllRead(userId);
                      ref.invalidate(myNotificationsProvider(userId));
                      ref.invalidate(unreadNotificationsCountProvider(userId));
                    },
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: FactorySpacing.space4,
                ),
                itemCount: notifications.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: FactorySpacing.space3),
                itemBuilder: (context, index) => _NotificationTile(
                  notification: notifications[index],
                  userId: userId,
                ),
              ),
            ),
            const SizedBox(height: FactorySpacing.space3),
          ],
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorNotificationsLoadFailed,
            onRetry: () => ref.invalidate(myNotificationsProvider(userId)),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.userId});

  final AppNotification notification;
  final String userId;

  IconData get _icon => switch (notification.type) {
    'BOOKING_CONFIRMED' => Icons.event_available_rounded,
    'BOOKING_CANCELLED' => Icons.event_busy_rounded,
    'BOOKING_REMINDER' => Icons.notifications_active_rounded,
    'PAYMENT_REFUNDED' => Icons.currency_exchange_rounded,
    _ => Icons.notifications_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      onTap: notification.read
          ? null
          : () async {
              await ref
                  .read(notificationsApiProvider)
                  .markRead(userId, notification.id);
              ref.invalidate(myNotificationsProvider(userId));
              ref.invalidate(unreadNotificationsCountProvider(userId));
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notification.read ? colors.surfaceAlt : colors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icon,
              size: 20,
              color: notification.read ? colors.textSecondary : colors.primary,
            ),
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: notification.read
                        ? FontWeight.w400
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: FactorySpacing.space1),
                Text(
                  notification.body,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: FactorySpacing.space1),
                Text(
                  formatMonthDayTime(l10n, notification.createdAt.toLocal()),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.read) ...[
            const SizedBox(width: FactorySpacing.space2),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

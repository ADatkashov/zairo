import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../data/models/app_notification.dart';
import '../../notification_destination.dart';
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
                icon: Symbols.notifications_rounded,
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
        Future<void> refresh() =>
            ref.refresh(myNotificationsProvider(userId).future);

        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: FactoryEmptyState(
                      icon: Symbols.notifications_rounded,
                      title: l10n.notificationsEmptyTitle,
                      message: l10n.notificationsEmptyMessage,
                    ),
                  ),
                ),
              ],
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
              child: RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FactorySpacing.space4,
                  ),
                  children: _withDayHeadings(context, notifications, userId),
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

/// The notifications (already newest first) with a heading — "Today",
/// "Yesterday" or the date — before the first one of each day.
List<Widget> _withDayHeadings(
  BuildContext context,
  List<AppNotification> notifications,
  String userId,
) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).toString();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  String label(DateTime day) {
    if (day == today) return l10n.notificationsGroupToday;
    if (day == yesterday) return l10n.notificationsGroupYesterday;
    return DateFormat.MMMMd(locale).format(day);
  }

  final children = <Widget>[];
  DateTime? current;
  for (final notification in notifications) {
    final local = notification.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (day != current) {
      current = day;
      children.add(_DayHeading(label: label(day)));
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
        child: _NotificationTile(notification: notification, userId: userId),
      ),
    );
  }
  return children;
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Padding(
      padding: const EdgeInsets.only(
        top: FactorySpacing.space2,
        bottom: FactorySpacing.space2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: colors.textSecondary),
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
    'BOOKING_CONFIRMED' => Symbols.event_available_rounded,
    'BOOKING_CANCELLED' => Symbols.event_busy_rounded,
    'BOOKING_REMINDER' => Symbols.notifications_active_rounded,
    'PAYMENT_REFUNDED' => Symbols.currency_exchange_rounded,
    _ => Symbols.notifications_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final destination = notificationDestination(notification.type);

    return FactoryCard(
      onTap: notification.read && destination == null
          ? null
          : () async {
              // Capture before awaiting: opening the destination replaces
              // this screen, and the router must not be looked up afterwards.
              final router = destination == null
                  ? null
                  : GoRouter.maybeOf(context);
              if (!notification.read) {
                await ref
                    .read(notificationsApiProvider)
                    .markRead(userId, notification.id);
                ref.invalidate(myNotificationsProvider(userId));
                ref.invalidate(unreadNotificationsCountProvider(userId));
              }
              if (destination != null) router?.go(destination);
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
          if (destination != null && notification.read) ...[
            const SizedBox(width: FactorySpacing.space2),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
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

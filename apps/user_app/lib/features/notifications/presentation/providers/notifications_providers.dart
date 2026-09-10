import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import '../../data/notifications_api.dart';

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(dioClientProvider));
});

final myNotificationsProvider = FutureProvider.autoDispose
    .family<List<AppNotification>, String>((ref, userId) {
      return ref.watch(notificationsApiProvider).listNotifications(userId);
    });

/// The Home bell icon's badge count — a separate, smaller request from
/// [myNotificationsProvider] rather than deriving the count client-side
/// from that list, so the badge can refresh (e.g. on Home's own
/// pull-to-refresh) without pulling the full notification history.
final unreadNotificationsCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, userId) {
      return ref.watch(notificationsApiProvider).unreadCount(userId);
    });

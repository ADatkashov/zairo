import 'package:core_network/core_network.dart';

import 'models/app_notification.dart';

/// Not final: tests substitute a subclass overriding these methods instead
/// of mocking Dio — same pattern as the other feature APIs.
class NotificationsApi {
  final DioClient _dioClient;

  NotificationsApi(this._dioClient);

  Future<List<AppNotification>> listNotifications(String userId) async {
    final response = await _dioClient.get('/users/$userId/notifications');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount(String userId) async {
    final response = await _dioClient.get(
      '/users/$userId/notifications/unread-count',
    );
    return (response.data as Map<String, dynamic>)['count'] as int;
  }

  Future<void> markRead(String userId, String notificationId) {
    return _dioClient.post('/users/$userId/notifications/$notificationId/read');
  }

  Future<void> markAllRead(String userId) {
    return _dioClient.post('/users/$userId/notifications/read-all');
  }
}

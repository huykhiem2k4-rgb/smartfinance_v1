import '../datasources/supabase_datasource.dart';
import '../datasources/local_datasource.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  NotificationRepository({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

  Future<List<NotificationModel>> getNotifications(String userId, {bool? unreadOnly}) async {
    final localData = await _local.getNotifications(userId, unreadOnly: unreadOnly);
    if (await ConnectivityHelper.isOnline) {
      try {
        final cloudData = await _cloud.getNotifications(userId, unreadOnly: unreadOnly);
        if (cloudData.isNotEmpty) return cloudData;
      } catch (_) {}
    }
    return localData;
  }

  Future<int> getUnreadCount(String userId) async {
    return _local.getUnreadNotificationCount(userId);
  }

  Future<void> markRead(String notificationId) async {
    await _local.markNotificationRead(notificationId);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.markNotificationRead(notificationId);
      } catch (_) {}
    }
  }

  Future<void> markAllRead(String userId) async {
    await _local.markAllNotificationsRead(userId);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.markAllNotificationsRead(userId);
      } catch (_) {}
    }
  }

  Future<void> create({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
  }) async {
    await _local.insertNotification(userId: userId, title: title, message: message, type: type, referenceId: referenceId);
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.insertNotification(userId: userId, title: title, message: message, type: type, referenceId: referenceId);
      } catch (_) {}
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../../data/models/notification_model.dart';
import '../../../core/theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await context.read<AppProvider>().loadNotifications();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final notifications = prov.notifications;
    final unreadCount = prov.unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              tooltip: 'Đánh dấu tất cả đã đọc',
              onPressed: () => prov.markAllNotificationsRead(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.notifications_none, size: 56, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('Chưa có thông báo', style: TextStyle(color: Colors.grey)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: notifications.length,
                  itemBuilder: (_, i) => _NotificationTile(
                    notification: notifications[i],
                    onTap: () => prov.markNotificationRead(notifications[i].notificationId),
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _typeIcon {
    switch (notification.type) {
      case 'TRANSACTION':
        return Icons.swap_horiz;
      case 'INVOICE':
        return Icons.receipt_long;
      default:
        return Icons.info_outline;
    }
  }

  Color get _typeColor {
    switch (notification.type) {
      case 'TRANSACTION':
        return AppColors.primary;
      case 'INVOICE':
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Container(
      color: isUnread ? AppColors.primary.withValues(alpha: 0.05) : null,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_typeIcon, color: _typeColor, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          notification.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _timeAgo(notification.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

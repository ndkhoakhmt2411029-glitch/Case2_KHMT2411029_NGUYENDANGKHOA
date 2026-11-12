import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient.instance;

  /// GET /notifications
  Future<List<AppNotification>> getAll() async {
    final data = await _api.get('/notifications');
    return ((data['notifications'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  /// GET /notifications/unread-count
  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  /// PATCH /notifications/:id/read
  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  /// PATCH /notifications/read-all
  Future<void> markAllRead() async {
    await _api.patch('/notifications/read-all');
  }
}

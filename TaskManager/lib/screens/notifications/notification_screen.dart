import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../tasks/task_detail_screen.dart';

/// Danh sách thông báo: giao việc, chia sẻ, thay đổi trạng thái/hạn.
/// Bấm vào thông báo để đánh dấu đã đọc và mở công việc liên quan.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _service.getAll();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markAll() async {
    try {
      await _service.markAllRead();
      if (mounted) {
        setState(() => _items = _items.map((n) => n.copyWith(isRead: true)).toList());
      }
      _snack('Đã đánh dấu tất cả là đã đọc');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _service.markRead(n.id);
        if (mounted) {
          setState(() => _items =
              _items.map((x) => x.id == n.id ? x.copyWith(isRead: true) : x).toList());
        }
      } on ApiException catch (e) {
        _snack(e.message);
      }
    }
    if (n.taskId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: n.taskId!)),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'task_due_changed':
        return Icons.event_repeat_outlined;
      default:
        return Icons.sync_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (hasUnread)
            TextButton(onPressed: _markAll, child: const Text('Đọc tất cả')),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Chưa có thông báo nào')),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            return ListTile(
                              leading: CircleAvatar(child: Icon(_icon(n.type))),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                    fontWeight:
                                        n.isRead ? FontWeight.normal : FontWeight.bold),
                              ),
                              subtitle: Text(
                                  '${n.message}\n${DateFormatter.dateTime(n.createdAt)}'),
                              isThreeLine: true,
                              trailing: n.isRead
                                  ? null
                                  : const Icon(Icons.circle, size: 10, color: Colors.blue),
                              onTap: () => _open(n),
                            );
                          },
                        ),
                ),
    );
  }
}

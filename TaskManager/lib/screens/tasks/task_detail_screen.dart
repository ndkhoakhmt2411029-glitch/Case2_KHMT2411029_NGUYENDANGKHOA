import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';

/// Chi tiết công việc (chỉ xem). Sửa/xóa/giao việc/chia sẻ làm ở các buổi sau.
class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = TaskService();
  Task? _task;
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
      _task = await _service.getTask(widget.taskId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _row(IconData icon, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _body(Task t) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            StatusBadge(status: t.status),
            const SizedBox(width: 12),
            PriorityBadge(priority: t.priority),
            if (t.isOverdue) ...[
              const SizedBox(width: 12),
              const Text('Quá hạn',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
          const Divider(height: 32),
          Text('Mô tả', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(t.description.isEmpty ? 'Không có mô tả' : t.description),
          const Divider(height: 32),
          _row(Icons.play_arrow_outlined, 'Bắt đầu',
              Text(DateFormatter.date(t.startDate))),
          _row(Icons.event, 'Hạn hoàn thành',
              Text(DateFormatter.date(t.dueDate))),
          _row(Icons.person_outline, 'Người tạo', Text(t.creator?.label ?? '—')),
          _row(Icons.star_outline, 'Phụ trách chính',
              Text(t.primaryAssignee?.label ?? '—')),
          _row(
            Icons.group_outlined,
            'Người được giao',
            t.assignees.isEmpty
                ? const Text('Chưa giao cho ai')
                : Wrap(
                    spacing: 6,
                    children: t.assignees
                        .map((u) => Chip(
                              label: Text(u.label),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
          ),
          _row(Icons.schedule, 'Tạo lúc', Text(DateFormatter.dateTime(t.createdAt))),
          _row(Icons.update, 'Cập nhật', Text(DateFormatter.dateTime(t.updatedAt))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết công việc')),
      body: _loading && t == null
          ? const LoadingView()
          : _error != null && t == null
              ? ErrorView(message: _error!, onRetry: _load)
              : _body(t!),
    );
  }
}

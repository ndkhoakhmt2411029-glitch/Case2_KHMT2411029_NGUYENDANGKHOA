import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/task_card.dart';
import 'task_form_screen.dart';

/// Pop với true nếu dữ liệu đã thay đổi để màn hình danh sách tải lại.
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
  bool _changed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await _service.getTask(widget.taskId);
      if (mounted) setState(() => _task = t);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: _task)));
    if (saved == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _changeStatus(String status) async {
    if (status == _task!.status) return;
    setState(() => _busy = true);
    try {
      final t = await _service.updateStatus(_task!.id, status);
      _changed = true;
      if (mounted) setState(() => _task = t);
      _snack('Đã cập nhật trạng thái');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: Text('Bạn có chắc muốn xóa "${_task!.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _service.deleteTask(_task!.id);
      if (!mounted) return;
      _snack('Đã xóa công việc');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(IconData icon, String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey))),
            Expanded(child: value),
          ],
        ),
      );

  String _names(List<User> users) =>
      users.isEmpty ? 'Chưa có' : users.map((u) => u.fullName).join(', ');

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          actions: [
            if (t != null && t.canEdit)
              IconButton(
                  tooltip: 'Chỉnh sửa',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy ? null : _edit),
            if (t != null && t.canDelete)
              IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : _delete),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  )
                : _buildContent(t!),
      ),
    );
  }

  Widget _buildContent(Task t) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(t.title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          StatusBadge(status: t.status),
          const SizedBox(width: 12),
          PriorityBadge(priority: t.priority),
          const Spacer(),
          Text(TaskCard.roleLabel(t.myRole),
              style: theme.textTheme.bodySmall),
        ]),
        const SizedBox(height: 16),
        if (t.canChangeStatus) ...[
          Text('Cập nhật trạng thái', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final s in TaskStatus.all)
                ButtonSegment(
                    value: s,
                    label: Text(TaskStatus.label(s),
                        style: const TextStyle(fontSize: 12))),
            ],
            selected: {t.status},
            onSelectionChanged:
                _busy ? null : (s) => _changeStatus(s.first),
          ),
          const SizedBox(height: 8),
        ],
        const Divider(height: 32),
        _row(Icons.notes, 'Mô tả',
            Text(t.description.isEmpty ? 'Không có mô tả' : t.description)),
        _row(Icons.play_circle_outline, 'Bắt đầu',
            Text(DateFormatter.date(t.startDate))),
        _row(
            Icons.event,
            'Hạn hoàn thành',
            Text(
              DateFormatter.date(t.dueDate) + (t.isOverdue ? ' (quá hạn)' : ''),
              style: TextStyle(
                  color: t.isOverdue ? theme.colorScheme.error : null),
            )),
        _row(Icons.person_outline, 'Người tạo',
            Text(t.createdBy?.fullName ?? '—')),
        _row(Icons.star_outline, 'Phụ trách chính',
            Text(t.primaryAssignee?.fullName ?? 'Chưa có')),
        _row(Icons.groups_outlined, 'Người được giao', Text(_names(t.assignees))),
        _row(Icons.schedule, 'Ngày tạo', Text(DateFormatter.dateTime(t.createdAt))),
      ],
    );
  }
}

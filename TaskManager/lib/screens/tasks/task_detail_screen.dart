import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../assignment/assign_task_screen.dart';
import '../sharing/task_sharing_screen.dart';
import 'task_edit_screen.dart';

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
  bool _changed = false; // báo cho màn hình danh sách tải lại

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
      _task = await _service.getTask(widget.taskId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskEditScreen(task: _task!)),
    );
    if (ok == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _openAssign(Task t) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssignTaskScreen(task: t)),
    );
    _changed = true;
    _load();
  }

  Future<void> _openShares(Task t) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskSharingScreen(task: t)),
    );
    _changed = true;
    _load();
  }

  Future<void> _changeStatus(String status) async {
    if (status == _task!.status) return;
    try {
      await _service.updateStatus(_task!.id, status);
      _changed = true;
      _snack('Đã cập nhật trạng thái');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
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
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteTask(_task!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (t.canEdit)
                OutlinedButton.icon(
                  onPressed: () => _openAssign(t),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Giao việc'),
                ),
              OutlinedButton.icon(
                onPressed: () => _openShares(t),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Chia sẻ'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Mô tả', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(t.description.isEmpty ? 'Không có mô tả' : t.description),
          const Divider(height: 32),
          _row(Icons.play_arrow_outlined, 'Bắt đầu',
              Text(DateFormatter.date(t.startDate))),
          _row(Icons.event, 'Hạn hoàn thành',
              Text(DateFormatter.date(t.dueDate))),
          _row(Icons.person_outline, 'Người tạo',
              Text(t.creator?.label ?? '—')),
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
          if (t.canChangeStatus) ...[
            const Divider(height: 32),
            Text('Cập nhật trạng thái', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: TaskStatus.all
                  .map((s) => ButtonSegment(
                      value: s,
                      label: Text(TaskStatus.label(s),
                          style: const TextStyle(fontSize: 12))))
                  .toList(),
              selected: {t.status},
              onSelectionChanged: (s) => _changeStatus(s.first),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          actions: [
            if (t != null && t.canEdit)
              IconButton(
                  tooltip: 'Chỉnh sửa',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit),
            if (t != null && t.canDelete)
              IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete),
          ],
        ),
        body: _loading && t == null
            ? const LoadingView()
            : _error != null && t == null
                ? ErrorView(message: _error!, onRetry: _load)
                : _body(t!),
      ),
    );
  }
}

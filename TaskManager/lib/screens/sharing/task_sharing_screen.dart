import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../services/api_client.dart';
import '../../services/task_share_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';

/// Xem danh sách chia sẻ; người tạo có thể thêm, đổi quyền viewer/editor và thu hồi.
class TaskSharingScreen extends StatefulWidget {
  final Task task;
  const TaskSharingScreen({super.key, required this.task});

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  final _service = TaskShareService();
  List<TaskShare> _shares = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // Chỉ người tạo (owner) được quản lý chia sẻ; editor không mặc nhiên có quyền này.
  bool get _canManage => widget.task.canDelete;

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
      _shares = await _service.getShares(widget.task.id);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePermission(TaskShare s, String permission) async {
    if (permission == s.permission) return;
    setState(() => _busy = true);
    try {
      final list =
          await _service.updatePermission(widget.task.id, s.id, permission);
      if (mounted) setState(() => _shares = list);
      _snack('Đã đổi quyền');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(TaskShare s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi quyền'),
        content: Text('Thu hồi quyền truy cập của ${s.user?.label ?? 'người này'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thu hồi')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final list = await _service.revoke(widget.task.id, s.id);
      if (mounted) setState(() => _shares = list);
      _snack('Đã thu hồi quyền');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAdd() async {
    final list = await showModalBottomSheet<List<TaskShare>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddShareSheet(
        task: widget.task,
        service: _service,
        existingIds: _shares.map((s) => s.user?.id ?? '').toSet(),
      ),
    );
    if (list != null && mounted) {
      setState(() => _shares = list);
      _snack('Đã chia sẻ công việc');
    }
  }

  Widget _tile(TaskShare s) {
    final user = s.user;
    return ListTile(
      leading: CircleAvatar(
        child: Text((user?.label ?? '?').isNotEmpty
            ? (user?.label ?? '?')[0].toUpperCase()
            : '?'),
      ),
      title: Text(user?.label ?? 'Người dùng đã bị xóa'),
      subtitle: Text(user?.email ?? ''),
      trailing: _canManage
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<String>(
                value: s.permission,
                underline: const SizedBox.shrink(),
                items: [
                  for (final p in TaskShare.permissions)
                    DropdownMenuItem(
                        value: p,
                        child: Text(p == TaskShare.editor ? 'Editor' : 'Viewer')),
                ],
                onChanged: _busy ? null : (v) => _changePermission(s, v ?? s.permission),
              ),
              IconButton(
                tooltip: 'Thu hồi quyền',
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: _busy ? null : () => _revoke(s),
              ),
            ])
          : Text(s.permission == TaskShare.editor ? 'Editor' : 'Viewer'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ công việc')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _shares.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Chưa chia sẻ cho ai')),
                        ])
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 88),
                          children: [for (final s in _shares) _tile(s)],
                        ),
                ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _openAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Chia sẻ'),
            )
          : null,
    );
  }
}

class _AddShareSheet extends StatefulWidget {
  final Task task;
  final TaskShareService service;
  final Set<String> existingIds;
  const _AddShareSheet({
    required this.task,
    required this.service,
    required this.existingIds,
  });

  @override
  State<_AddShareSheet> createState() => _AddShareSheetState();
}

class _AddShareSheetState extends State<_AddShareSheet> {
  List<PersonRef> _selected = [];
  String _permission = TaskShare.viewer;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Vui lòng chọn ít nhất một người');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final list = await widget.service.addShares(widget.task.id,
          people: _selected, permission: _permission);
      if (mounted) Navigator.pop(context, list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chia sẻ công việc',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            UserSelector(
              selected: _selected,
              excludeIds: widget.existingIds,
              onChanged: (list) => setState(() => _selected = list),
            ),
            const SizedBox(height: 16),
            const Text('Quyền truy cập'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TaskShare.viewer, label: Text('Chỉ xem')),
                ButtonSegment(value: TaskShare.editor, label: Text('Chỉnh sửa')),
              ],
              selected: {_permission},
              onSelectionChanged: (s) => setState(() => _permission = s.first),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Chia sẻ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

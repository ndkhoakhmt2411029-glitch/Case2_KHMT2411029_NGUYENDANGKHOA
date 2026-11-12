import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../services/api_client.dart';
import '../../services/assignment_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/user_selector.dart';

/// Giao công việc cho một hoặc nhiều người và chọn người phụ trách chính.
class AssignTaskScreen extends StatefulWidget {
  final Task task;
  const AssignTaskScreen({super.key, required this.task});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _service = AssignmentService();
  AssignmentResult? _current;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<PersonRef> _selected = [];
  String? _primaryKey; // khóa của người được chọn làm phụ trách chính (trong danh sách mới chọn)

  bool get _canManage => widget.task.canEdit;

  String _key(PersonRef p) => p.id.isNotEmpty ? p.id : p.email.toLowerCase();

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
      _current = await _service.getAssignees(widget.task.id);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      _snack('Vui lòng chọn ít nhất một người', error: true);
      return;
    }
    PersonRef? primary;
    for (final p in _selected) {
      if (_key(p) == _primaryKey) primary = p;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.assign(
        widget.task.id,
        userIds: _selected.where((p) => p.id.isNotEmpty).map((p) => p.id).toList(),
        emails: _selected.where((p) => p.id.isEmpty).map((p) => p.email).toList(),
        primaryAssigneeId: (primary != null && primary.id.isNotEmpty) ? primary.id : null,
        primaryEmail: (primary != null && primary.id.isEmpty) ? primary.email : null,
      );
      if (!mounted) return;
      setState(() {
        _current = result;
        _selected = [];
        _primaryKey = null;
      });
      _snack('Đã giao việc');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makePrimary(Assignee a) async {
    setState(() => _busy = true);
    try {
      final result = await _service.setPrimary(widget.task.id, a.person.id);
      if (mounted) setState(() => _current = result);
      _snack('Đã đổi người phụ trách chính');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Assignee a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy giao việc'),
        content: Text('Hủy giao việc cho ${a.person.label}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hủy giao')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final result = await _service.remove(widget.task.id, a.person.id);
      if (mounted) setState(() => _current = result);
      _snack('Đã hủy giao việc');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _currentList() {
    final list = _current?.assignees ?? [];
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Chưa giao cho ai'),
      );
    }
    return Column(
      children: [
        for (final a in list)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(a.person.label.isNotEmpty
                  ? a.person.label[0].toUpperCase()
                  : '?'),
            ),
            title: Text(a.person.label),
            subtitle: Text(a.isPrimary
                ? '${a.person.email} • Phụ trách chính'
                : a.person.email),
            trailing: _canManage
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Đặt làm người phụ trách chính',
                      icon: Icon(a.isPrimary ? Icons.star : Icons.star_border,
                          color: a.isPrimary ? Colors.amber : null),
                      onPressed: (_busy || a.isPrimary) ? null : () => _makePrimary(a),
                    ),
                    IconButton(
                      tooltip: 'Hủy giao việc',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: _busy ? null : () => _remove(a),
                    ),
                  ])
                : (a.isPrimary
                    ? const Icon(Icons.star, color: Colors.amber)
                    : null),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existingIds = (_current?.assignees ?? []).map((a) => a.person.id).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Giao công việc')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(widget.task.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('Đang được giao', style: theme.textTheme.titleSmall),
                    _currentList(),
                    if (_canManage) ...[
                      const Divider(height: 32),
                      Text('Giao thêm cho', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      UserSelector(
                        selected: _selected,
                        excludeIds: existingIds,
                        onChanged: (list) => setState(() {
                          _selected = list;
                          if (!list.any((p) => _key(p) == _primaryKey)) {
                            _primaryKey = null;
                          }
                        }),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          initialValue: _primaryKey,
                          decoration: const InputDecoration(
                            labelText: 'Người phụ trách chính (tùy chọn)',
                            prefixIcon: Icon(Icons.star_outline),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Tự động (người đầu tiên)')),
                            for (final p in _selected)
                              DropdownMenuItem<String?>(
                                  value: _key(p), child: Text(p.label)),
                          ],
                          onChanged: (v) => setState(() => _primaryKey = v),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Xác nhận giao việc'),
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text('Bạn không có quyền thay đổi người được giao.'),
                      ),
                  ],
                ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../widgets/task_card.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _service = TaskService();
  final _auth = AuthService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  String _scope = 'all';
  String? _status;
  String? _priority;
  String _sortBy = 'createdAt';
  String _order = 'desc';

  static const _scopes = {
    'all': 'Tất cả',
    'created': 'Của tôi',
    'assigned': 'Được giao',
    'shared': 'Được chia sẻ',
  };

  static const _sorts = {
    'dueDate': 'Hạn hoàn thành',
    'priority': 'Mức độ ưu tiên',
    'createdAt': 'Thời gian tạo',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tasks = await _service.getTasks(
        scope: _scope,
        status: _status,
        priority: _priority,
        q: _searchCtrl.text,
        sortBy: _sortBy,
        order: _order,
      );
      if (mounted) setState(() => _tasks = tasks);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.logout();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TaskFormScreen()));
    if (created == true) _load();
  }

  Future<void> _openDetail(Task t) async {
    final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));
    if (changed == true) _load();
  }

  bool get _hasFilter => _status != null || _priority != null;

  Future<void> _openFilters() async {
    String? status = _status;
    String? priority = _priority;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lọc công việc', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Text('Trạng thái'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final s in TaskStatus.all)
                  ChoiceChip(
                    label: Text(TaskStatus.label(s)),
                    selected: status == s,
                    onSelected: (v) => setSheet(() => status = v ? s : null),
                  ),
              ]),
              const SizedBox(height: 16),
              const Text('Mức độ ưu tiên'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final p in TaskPriority.all)
                  ChoiceChip(
                    label: Text(TaskPriority.label(p)),
                    selected: priority == p,
                    onSelected: (v) => setSheet(() => priority = v ? p : null),
                  ),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setSheet(() {
                      status = null;
                      priority = null;
                    }),
                    child: const Text('Xóa lọc'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _status = status;
        _priority = priority;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          IconButton(
            tooltip: 'Lọc',
            icon: Badge(
                isLabelVisible: _hasFilter,
                smallSize: 8,
                child: const Icon(Icons.filter_list)),
            onPressed: _openFilters,
          ),
          PopupMenuButton<String>(
            tooltip: 'Sắp xếp',
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() {
                if (v == _sortBy) {
                  _order = _order == 'asc' ? 'desc' : 'asc';
                } else {
                  _sortBy = v;
                  _order = v == 'createdAt' ? 'desc' : 'asc';
                }
              });
              _load();
            },
            itemBuilder: (_) => [
              for (final e in _sorts.entries)
                PopupMenuItem(
                  value: e.key,
                  child: Row(children: [
                    SizedBox(
                      width: 24,
                      child: _sortBy == e.key
                          ? Icon(
                              _order == 'asc'
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 18)
                          : null,
                    ),
                    Text(e.value),
                  ]),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên công việc',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                          _load();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final e in _scopes.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _scope == e.key,
                      onSelected: (_) {
                        setState(() => _scope = e.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: ListView(children: const [
          SizedBox(height: 120),
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('Không có công việc nào')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88, top: 4),
        itemCount: _tasks.length,
        itemBuilder: (_, i) =>
            TaskCard(task: _tasks[i], onTap: () => _openDetail(_tasks[i])),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/task_card.dart';
import '../stats/stats_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

/// Danh sách công việc: phân loại, tìm kiếm theo tên, lọc (trạng thái, ưu tiên, người phụ trách), sắp xếp.
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

  // Bộ lọc
  String? _scope; // null = tất cả
  String? _status;
  String? _priority;
  String? _assigneeId;
  String _sortBy = 'createdAt';
  String _order = 'desc';

  // Những người đã gặp trong kết quả, dùng cho bộ lọc "người phụ trách"
  final Map<String, String> _people = {};

  static const _scopes = <String?, String>{
    null: 'Tất cả',
    'created': 'Của tôi',
    'assigned': 'Được giao',
    'shared': 'Được chia sẻ',
  };

  static const _sorts = <String, String>{
    'createdAt': 'Thời gian tạo',
    'dueDate': 'Hạn hoàn thành',
    'priority': 'Mức độ ưu tiên',
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getTasks(
        scope: _scope,
        status: _status,
        priority: _priority,
        assigneeId: _assigneeId,
        q: _searchCtrl.text,
        sortBy: _sortBy,
        order: _order,
      );
      for (final t in list) {
        final p = t.primaryAssignee;
        if (p != null && p.id.isNotEmpty) _people[p.id] = p.label;
      }
      if (mounted) setState(() => _tasks = list);
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
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openDetail(Task t) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
    );
    if (changed == true) _load();
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
    );
    if (ok == true) _load();
  }

  Widget _dropdown<T>({
    required String hint,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButton<T>(
      isExpanded: true,
      value: value,
      hint: Text(hint),
      underline: const SizedBox.shrink(),
      items: items.entries
          .map((e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _filterBar() {
    final people = <String?, String>{
      null: 'Mọi người phụ trách',
      ..._people,
    };
    // Giữ giá trị đang chọn hợp lệ
    final assignee = people.containsKey(_assigneeId) ? _assigneeId : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
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
                        _load();
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _scopes.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: _scope == e.key,
                          onSelected: (_) {
                            setState(() => _scope = e.key);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _dropdown<String?>(
                  hint: 'Trạng thái',
                  value: _status,
                  items: {
                    null: 'Mọi trạng thái',
                    for (final s in TaskStatus.all) s: TaskStatus.label(s),
                  },
                  onChanged: (v) {
                    setState(() => _status = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown<String?>(
                  hint: 'Ưu tiên',
                  value: _priority,
                  items: {
                    null: 'Mọi mức ưu tiên',
                    for (final p in TaskPriority.all) p: TaskPriority.label(p),
                  },
                  onChanged: (v) {
                    setState(() => _priority = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          _dropdown<String?>(
            hint: 'Người phụ trách',
            value: assignee,
            items: people,
            onChanged: (v) {
              setState(() => _assigneeId = v);
              _load();
            },
          ),
          Row(
            children: [
              Expanded(
                child: _dropdown<String>(
                  hint: 'Sắp xếp',
                  value: _sortBy,
                  items: _sorts,
                  onChanged: (v) {
                    setState(() => _sortBy = v ?? _sortBy);
                    _load();
                  },
                ),
              ),
              IconButton(
                tooltip: _order == 'asc' ? 'Tăng dần' : 'Giảm dần',
                icon: Icon(_order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () {
                  setState(() => _order = _order == 'asc' ? 'desc' : 'asc');
                  _load();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading && _tasks.isEmpty) return const LoadingView();
    if (_error != null && _tasks.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _tasks.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Không có công việc phù hợp')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _tasks.length,
              itemBuilder: (_, i) => TaskCard(
                task: _tasks[i],
                onTap: () => _openDetail(_tasks[i]),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          IconButton(
            tooltip: 'Thống kê',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          const NotificationBell(),
          IconButton(
            tooltip: 'Cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          if (_loading && _tasks.isNotEmpty) const LinearProgressIndicator(),
          Expanded(child: _list()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),
    );
  }
}

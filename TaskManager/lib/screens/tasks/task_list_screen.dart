import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/task_card.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

/// Danh sách công việc liên quan đến người dùng (đọc từ MongoDB qua API).
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _service = TaskService();
  final _auth = AuthService();

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;
  String? _scope; // null = tất cả

  static const _scopes = <String?, String>{
    null: 'Tất cả',
    'created': 'Của tôi',
    'assigned': 'Được giao',
    'shared': 'Được chia sẻ',
  };

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
      final list = await _service.getTasks(scope: _scope);
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

  Widget _scopeBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
              Center(child: Text('Chưa có công việc nào')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
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
            tooltip: 'Cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          _scopeBar(),
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

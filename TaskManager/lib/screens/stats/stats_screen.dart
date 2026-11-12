import 'package:flutter/material.dart';

import '../../models/stats.dart';
import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/stats_service.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/loading_view.dart';
import '../tasks/task_detail_screen.dart';

/// Thống kê: theo trạng thái, được giao / phụ trách chính, sắp đến hạn và quá hạn.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _service = StatsService();
  StatsSummary? _stats;
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
      _stats = await _service.getSummary();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _countsCard(String title, StatusCounts c) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold))),
              Text('${c.total} việc'),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: c.total == 0 ? 0 : c.completed / c.total,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text('${c.percent}% hoàn thành'),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 4, children: [
              _dot('Chưa thực hiện', c.todo, Colors.grey),
              _dot('Đang thực hiện', c.inProgress, Colors.blue),
              _dot('Đã hoàn thành', c.completed, Colors.green),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _dot(String label, int n, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 4),
          Text('$label: $n'),
        ],
      );

  Widget _taskList(String title, List<StatsTask> tasks, Color color, String empty) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${tasks.length})',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            if (tasks.isEmpty) Text(empty),
            for (final t in tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.title),
                subtitle: Text(
                    '${TaskStatus.label(t.status)} • Hạn: ${DateFormatter.date(t.dueDate)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: _loading && s == null
          ? const LoadingView()
          : _error != null && s == null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _countsCard('Tất cả công việc của tôi', s!.byStatus),
                      _countsCard('Được giao cho tôi', s.assignedToMe),
                      _countsCard('Tôi phụ trách chính', s.primaryByMe),
                      _taskList('Sắp đến hạn (${s.dueSoonDays} ngày tới)', s.dueSoon,
                          Colors.orange, 'Không có công việc sắp đến hạn'),
                      _taskList('Đã quá hạn', s.overdue, Colors.red,
                          'Không có công việc quá hạn'),
                    ],
                  ),
                ),
    );
  }
}

class StatusCounts {
  final int total, todo, inProgress, completed, percent;
  const StatusCounts({
    this.total = 0,
    this.todo = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.percent = 0,
  });

  factory StatusCounts.fromJson(dynamic j) {
    if (j is! Map) return const StatusCounts();
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return StatusCounts(
      total: n('total'),
      todo: n('todo'),
      inProgress: n('in_progress'),
      completed: n('completed'),
      percent: n('percent'),
    );
  }
}

class StatsTask {
  final String id, title, status, priority;
  final DateTime? dueDate;
  const StatsTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.dueDate,
  });

  factory StatsTask.fromJson(Map<String, dynamic> j) => StatsTask(
        id: (j['_id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        priority: (j['priority'] ?? '').toString(),
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.tryParse(j['dueDate'].toString())?.toLocal(),
      );
}

class StatsSummary {
  final StatusCounts byStatus, assignedToMe, primaryByMe;
  final List<StatsTask> dueSoon, overdue;
  final int dueSoonDays;

  const StatsSummary({
    required this.byStatus,
    required this.assignedToMe,
    required this.primaryByMe,
    required this.dueSoon,
    required this.overdue,
    required this.dueSoonDays,
  });

  static List<StatsTask> _tasks(dynamic v) => v is List
      ? v.whereType<Map<String, dynamic>>().map(StatsTask.fromJson).toList()
      : const [];

  factory StatsSummary.fromJson(Map<String, dynamic> j) => StatsSummary(
        byStatus: StatusCounts.fromJson(j['byStatus']),
        assignedToMe: StatusCounts.fromJson(j['assignedToMe']),
        primaryByMe: StatusCounts.fromJson(j['primaryByMe']),
        dueSoon: _tasks(j['dueSoon']),
        overdue: _tasks(j['overdue']),
        dueSoonDays: (j['dueSoonDays'] as num?)?.toInt() ?? 3,
      );
}

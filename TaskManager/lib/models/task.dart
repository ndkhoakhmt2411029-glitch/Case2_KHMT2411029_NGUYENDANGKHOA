import 'user.dart';

class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const all = [todo, inProgress, completed];

  static String label(String s) {
    switch (s) {
      case todo:
        return 'Chưa thực hiện';
      case inProgress:
        return 'Đang thực hiện';
      case completed:
        return 'Đã hoàn thành';
    }
    return s;
  }
}

class TaskPriority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const all = [low, medium, high];

  static String label(String p) {
    switch (p) {
      case low:
        return 'Thấp';
      case medium:
        return 'Trung bình';
      case high:
        return 'Cao';
    }
    return p;
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final User? createdBy;
  final List<User> assignees;
  final User? primaryAssignee;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final DateTime? createdAt;

  /// owner | editor | assignee | viewer
  final String myRole;
  final bool canEdit;
  final bool canDelete;
  final bool canChangeStatus;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.createdBy,
    this.assignees = const [],
    this.primaryAssignee,
    this.startDate,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.createdAt,
    this.myRole = 'viewer',
    this.canEdit = false,
    this.canDelete = false,
    this.canChangeStatus = false,
  });

  bool get isOverdue =>
      dueDate != null &&
      status != TaskStatus.completed &&
      dueDate!.isBefore(DateTime.now());

  static User? _user(dynamic v) =>
      v is Map<String, dynamic> ? User.fromJson(v) : null;

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory Task.fromJson(Map<String, dynamic> json) {
    final perms = (json['permissions'] as Map<String, dynamic>?) ?? {};
    return Task(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdBy: _user(json['createdBy']),
      assignees: ((json['assigneeIds'] as List?) ?? [])
          .map(_user)
          .whereType<User>()
          .toList(),
      primaryAssignee: _user(json['primaryAssigneeId']),
      startDate: _date(json['startDate']),
      dueDate: _date(json['dueDate']),
      priority: (json['priority'] ?? TaskPriority.medium).toString(),
      status: (json['status'] ?? TaskStatus.todo).toString(),
      createdAt: _date(json['createdAt']),
      myRole: (json['myRole'] ?? 'viewer').toString(),
      canEdit: perms['canEdit'] == true,
      canDelete: perms['canDelete'] == true,
      canChangeStatus: perms['canChangeStatus'] == true,
    );
  }
}

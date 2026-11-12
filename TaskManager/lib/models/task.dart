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
      default:
        return s;
    }
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
      default:
        return p;
    }
  }
}

class TaskUser {
  final String id;
  final String name;
  const TaskUser({required this.id, required this.name});

  String get label => name.isEmpty ? id : name;

  static TaskUser? fromAny(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return TaskUser(
        id: (v['_id'] ?? v['id'] ?? '').toString(),
        name: (v['fullName'] ?? v['email'] ?? '').toString(),
      );
    }
    return TaskUser(id: v.toString(), name: '');
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final TaskUser? creator;
  final List<TaskUser> assignees;
  final TaskUser? primaryAssignee;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Vai trò của người đang đăng nhập (nếu backend trả về): owner / editor / assignee / viewer.
  final String? myPermission;

  /// Quyền chi tiết do backend trả về (permissions.canEdit...), nếu có.
  final Map<String, bool>? perms;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.creator,
    this.assignees = const [],
    this.primaryAssignee,
    this.startDate,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.createdAt,
    this.updatedAt,
    this.myPermission,
    this.perms,
  });

  bool get canEdit => perms != null
      ? perms!['canEdit'] == true
      : (myPermission == null || myPermission != 'viewer');

  bool get canDelete => perms != null
      ? perms!['canDelete'] == true
      : (myPermission == null || myPermission == 'owner');

  bool get canChangeStatus =>
      perms != null ? perms!['canChangeStatus'] == true : canEdit;

  bool get isOverdue =>
      dueDate != null &&
      status != TaskStatus.completed &&
      dueDate!.isBefore(DateTime.now());

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory Task.fromJson(Map<String, dynamic> j) {
    final rawAssignees = j['assigneeIds'] ?? j['assignees'];
    return Task(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      creator: TaskUser.fromAny(j['createdBy']),
      assignees: rawAssignees is List
          ? rawAssignees
              .map(TaskUser.fromAny)
              .whereType<TaskUser>()
              .toList()
          : const [],
      primaryAssignee: TaskUser.fromAny(j['primaryAssigneeId']),
      startDate: _date(j['startDate']),
      dueDate: _date(j['dueDate']),
      priority: (j['priority'] ?? TaskPriority.medium).toString(),
      status: (j['status'] ?? TaskStatus.todo).toString(),
      createdAt: _date(j['createdAt']),
      updatedAt: _date(j['updatedAt']),
      myPermission:
          (j['myRole'] ?? j['myPermission'] ?? j['permission'])?.toString(),
      perms: j['permissions'] is Map
          ? (j['permissions'] as Map)
              .map((k, v) => MapEntry(k.toString(), v == true))
          : null,
    );
  }
}

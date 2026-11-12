import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient _api = ApiClient.instance;

  List<Task> _parseList(Map<String, dynamic> data) {
    final raw = data['tasks'] ?? data['data'] ?? data['items'] ?? [];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  Task _parseOne(Map<String, dynamic> data) {
    final raw = data['task'] ?? data['data'] ?? data;
    return Task.fromJson(raw as Map<String, dynamic>);
  }

  /// GET /tasks?scope=&status=&priority=&q=&sortBy=&order=
  Future<List<Task>> getTasks({
    String? scope, // created | assigned | shared | null = tất cả
    String? status,
    String? priority,
    String? assigneeId, // lọc theo người phụ trách
    String? q,
    String sortBy = 'createdAt', // dueDate | priority | createdAt
    String order = 'desc', // asc | desc
  }) async {
    final query = <String, String>{
      if (scope != null) 'scope': scope,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'sortBy': sortBy,
      'order': order,
    };
    final path = Uri(path: '/tasks', queryParameters: query).toString();
    return _parseList(await _api.get(path));
  }

  /// GET /tasks/:id
  Future<Task> getTask(String id) async => _parseOne(await _api.get('/tasks/$id'));

  /// POST /tasks
  Future<Task> createTask({
    required String title,
    String description = '',
    DateTime? startDate,
    DateTime? dueDate,
    String priority = TaskPriority.medium,
    String status = TaskStatus.todo,
  }) async {
    final data = await _api.post('/tasks', body: {
      'title': title.trim(),
      'description': description.trim(),
      'startDate': startDate?.toUtc().toIso8601String(),
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'priority': priority,
      'status': status,
    });
    return _parseOne(data);
  }

  /// PUT /tasks/:id
  Future<Task> updateTask(
    String id, {
    required String title,
    String description = '',
    DateTime? startDate,
    DateTime? dueDate,
    required String priority,
    required String status,
  }) async {
    final data = await _api.put('/tasks/$id', body: {
      'title': title.trim(),
      'description': description.trim(),
      'startDate': startDate?.toUtc().toIso8601String(),
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'priority': priority,
      'status': status,
    });
    return _parseOne(data);
  }

  /// PATCH /tasks/:id/status
  Future<void> updateStatus(String id, String status) async {
    await _api.patch('/tasks/$id/status', body: {'status': status});
  }

  /// DELETE /tasks/:id
  Future<void> deleteTask(String id) async {
    await _api.delete('/tasks/$id');
  }
}

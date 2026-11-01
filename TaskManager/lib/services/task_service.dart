import '../models/task.dart';
import 'api_client.dart';

class TaskService {
  final ApiClient _api = ApiClient.instance;

  /// GET /tasks
  /// scope: all | created | assigned | shared
  Future<List<Task>> getTasks({
    String scope = 'all',
    String? status,
    String? priority,
    String? q,
    String? assigneeId,
    String sortBy = 'createdAt',
    String order = 'desc',
  }) async {
    final query = <String, String>{
      'scope': scope,
      'sortBy': sortBy,
      'order': order,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (assigneeId != null) 'assigneeId': assigneeId,
    };
    final path = Uri(path: '/tasks', queryParameters: query).toString();
    final data = await _api.get(path);
    return ((data['tasks'] as List?) ?? [])
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /tasks/:id
  Future<Task> getTask(String id) async {
    final data = await _api.get('/tasks/$id');
    return Task.fromJson(data['task'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _body({
    required String title,
    required String description,
    DateTime? startDate,
    DateTime? dueDate,
    required String priority,
    required String status,
  }) =>
      {
        'title': title.trim(),
        'description': description.trim(),
        'startDate': startDate?.toUtc().toIso8601String(),
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'priority': priority,
        'status': status,
      };

  /// POST /tasks
  Future<Task> createTask({
    required String title,
    String description = '',
    DateTime? startDate,
    DateTime? dueDate,
    String priority = TaskPriority.medium,
    String status = TaskStatus.todo,
  }) async {
    final data = await _api.post('/tasks',
        body: _body(
            title: title,
            description: description,
            startDate: startDate,
            dueDate: dueDate,
            priority: priority,
            status: status));
    return Task.fromJson(data['task'] as Map<String, dynamic>);
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
    final data = await _api.put('/tasks/$id',
        body: _body(
            title: title,
            description: description,
            startDate: startDate,
            dueDate: dueDate,
            priority: priority,
            status: status));
    return Task.fromJson(data['task'] as Map<String, dynamic>);
  }

  /// PATCH /tasks/:id/status
  Future<Task> updateStatus(String id, String status) async {
    final data = await _api.patch('/tasks/$id/status', body: {'status': status});
    return Task.fromJson(data['task'] as Map<String, dynamic>);
  }

  /// DELETE /tasks/:id
  Future<void> deleteTask(String id) async {
    await _api.delete('/tasks/$id');
  }
}

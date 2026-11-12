import '../models/task.dart';
import 'api_client.dart';

/// Buổi 1: chỉ đọc dữ liệu công việc (GET) từ backend/MongoDB.
class TaskService {
  final ApiClient _api = ApiClient.instance;

  /// GET /tasks?scope=created|assigned|shared
  Future<List<Task>> getTasks({String? scope}) async {
    final path = Uri(
      path: '/tasks',
      queryParameters: {if (scope != null) 'scope': scope},
    ).toString();
    final data = await _api.get(path);
    final raw = data['tasks'] ?? [];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
  }

  /// GET /tasks/:id
  Future<Task> getTask(String id) async {
    final data = await _api.get('/tasks/$id');
    return Task.fromJson((data['task'] ?? data) as Map<String, dynamic>);
  }
}

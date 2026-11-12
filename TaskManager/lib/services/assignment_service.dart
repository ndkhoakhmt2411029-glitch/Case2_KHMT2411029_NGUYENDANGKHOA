import '../models/task_share.dart';
import 'api_client.dart';

class AssignmentResult {
  final List<Assignee> assignees;
  final String? primaryId;
  const AssignmentResult({required this.assignees, this.primaryId});
}

class AssignmentService {
  final ApiClient _api = ApiClient.instance;

  AssignmentResult _parse(Map<String, dynamic> data) {
    final list = ((data['assignees'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((m) => Assignee(
              person: PersonRef.fromJson(m),
              isPrimary: m['isPrimary'] == true,
            ))
        .toList();
    return AssignmentResult(
      assignees: list,
      primaryId: data['primaryAssigneeId']?.toString(),
    );
  }

  /// GET /tasks/:id/assignees
  Future<AssignmentResult> getAssignees(String taskId) async =>
      _parse(await _api.get('/tasks/$taskId/assignees'));

  /// POST /tasks/:id/assignees
  Future<AssignmentResult> assign(
    String taskId, {
    List<String> userIds = const [],
    List<String> emails = const [],
    String? primaryAssigneeId,
    String? primaryEmail,
  }) async {
    final data = await _api.post('/tasks/$taskId/assignees', body: {
      'userIds': userIds,
      'emails': emails,
      if (primaryAssigneeId != null) 'primaryAssigneeId': primaryAssigneeId,
      if (primaryEmail != null) 'primaryEmail': primaryEmail,
    });
    return _parse(data);
  }

  /// PATCH /tasks/:id/assignees/:userId  (đặt người phụ trách chính)
  Future<AssignmentResult> setPrimary(String taskId, String userId) async =>
      _parse(await _api.patch('/tasks/$taskId/assignees/$userId'));

  /// DELETE /tasks/:id/assignees/:userId
  Future<AssignmentResult> remove(String taskId, String userId) async =>
      _parse(await _api.delete('/tasks/$taskId/assignees/$userId'));
}

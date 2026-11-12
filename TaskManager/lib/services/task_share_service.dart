import '../models/task_share.dart';
import 'api_client.dart';

class TaskShareService {
  final ApiClient _api = ApiClient.instance;

  List<TaskShare> _parse(Map<String, dynamic> data) =>
      ((data['shares'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TaskShare.fromJson)
          .toList();

  /// GET /tasks/:id/shares
  Future<List<TaskShare>> getShares(String taskId) async =>
      _parse(await _api.get('/tasks/$taskId/shares'));

  /// POST /tasks/:id/shares  (chia sẻ cho một hoặc nhiều người)
  Future<List<TaskShare>> addShares(
    String taskId, {
    required List<PersonRef> people,
    required String permission,
  }) async {
    final items = [
      for (final p in people)
        {
          if (p.id.isNotEmpty) 'userId': p.id else 'email': p.email,
          'permission': permission,
        },
    ];
    return _parse(await _api.post('/tasks/$taskId/shares', body: {'items': items}));
  }

  /// PATCH /tasks/:id/shares/:shareId
  Future<List<TaskShare>> updatePermission(
          String taskId, String shareId, String permission) async =>
      _parse(await _api.patch('/tasks/$taskId/shares/$shareId',
          body: {'permission': permission}));

  /// DELETE /tasks/:id/shares/:shareId  (thu hồi quyền)
  Future<List<TaskShare>> revoke(String taskId, String shareId) async =>
      _parse(await _api.delete('/tasks/$taskId/shares/$shareId'));
}

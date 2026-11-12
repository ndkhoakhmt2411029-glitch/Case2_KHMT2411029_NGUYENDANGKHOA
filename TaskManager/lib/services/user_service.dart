import '../models/task_share.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient.instance;

  /// GET /users/search?q=
  Future<List<PersonRef>> search(String q) async {
    final path =
        Uri(path: '/users/search', queryParameters: {'q': q.trim()}).toString();
    final data = await _api.get(path);
    return ((data['users'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PersonRef.fromJson)
        .toList();
  }
}

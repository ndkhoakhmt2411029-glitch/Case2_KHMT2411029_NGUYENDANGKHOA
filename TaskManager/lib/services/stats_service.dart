import '../models/stats.dart';
import 'api_client.dart';

class StatsService {
  final ApiClient _api = ApiClient.instance;

  /// GET /stats/summary?days=3
  Future<StatsSummary> getSummary({int days = 3}) async {
    final data = await _api.get('/stats/summary?days=$days');
    return StatsSummary.fromJson(data);
  }
}

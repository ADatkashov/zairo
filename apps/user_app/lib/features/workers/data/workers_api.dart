import 'package:core_network/core_network.dart';

import 'models/top_worker.dart';
import 'models/worker_profile.dart';

/// Not final: tests substitute a subclass overriding these methods instead of
/// mocking Dio — same pattern as AdsApi/StaffApi.
class WorkersApi {
  final DioClient _dioClient;

  WorkersApi(this._dioClient);

  Future<List<TopWorker>> listTop({int limit = 10}) async {
    final response = await _dioClient.get('/workers/top', queryParameters: {'limit': limit});
    final data = response.data as List<dynamic>;
    return data.map((e) => TopWorker.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkerProfile> getProfile(String workerId) async {
    final response = await _dioClient.get('/workers/$workerId');
    return WorkerProfile.fromJson(response.data as Map<String, dynamic>);
  }
}

import 'package:core_network/core_network.dart';

import 'models/platform_admin_session.dart';

/// Everything under `/api/v1/platform/auth/**` — a wholly separate login
/// from the regular business-owner one (`AuthApi`/`authTokenHolderProvider`).
/// See `CatalogApi`'s own doc comment for how the resulting token is used
/// against the catalog admin endpoints.
class PlatformAdminApi {
  final DioClient _dioClient;

  PlatformAdminApi(this._dioClient);

  Future<PlatformAdminSession> login({required String email, required String password}) async {
    final response = await _dioClient.post(
      '/platform/auth/login',
      data: {'email': email, 'password': password},
    );
    return PlatformAdminSession.fromJson(response.data as Map<String, dynamic>);
  }
}

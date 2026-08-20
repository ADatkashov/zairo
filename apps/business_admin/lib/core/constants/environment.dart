import 'package:core_network/core_network.dart';

/// Same local backend as apps/user_app — there's no deployed environment
/// yet. See apps/user_app/lib/core/constants/environment.dart for the
/// identical reasoning; kept as a separate constant per app rather than
/// shared, so each app's environment can diverge independently later
/// (e.g. Business Admin pointed at a staging API before the consumer app).
const NetworkConfig adminNetworkConfig = NetworkConfig(
  baseUrl: 'http://localhost:8080/api/v1',
);

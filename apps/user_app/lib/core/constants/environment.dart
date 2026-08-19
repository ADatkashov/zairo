import 'package:core_network/core_network.dart';

/// The app's own environment configuration — this is where a concrete
/// baseUrl is chosen, not inside core_network. Points at the local
/// backend (`backend/platform-api`, see infrastructure/docker-compose.yml)
/// since there's no deployed environment yet. Swap this out per flavor
/// (dev/staging/prod, via --dart-define or Flutter flavors) once a real
/// deployment exists to point at.
const NetworkConfig appNetworkConfig = NetworkConfig(
  baseUrl: 'http://localhost:8080/api/v1',
);

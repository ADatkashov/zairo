import 'package:core_network/core_network.dart';

/// The app's own environment configuration — this is where a concrete
/// baseUrl is chosen, not inside core_network. Swap this out per
/// flavor (dev/staging/prod) once flavors are introduced.
const NetworkConfig appNetworkConfig = NetworkConfig(
  baseUrl: 'https://api.zairo.com/v1',
);

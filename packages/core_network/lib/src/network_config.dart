import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connection settings for [core_network]. Apps must override
/// [networkConfigProvider] with their own values — this package has
/// no knowledge of which app or environment (dev/staging/prod) it runs in.
class NetworkConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const NetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
  });
}

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  throw UnimplementedError(
    'networkConfigProvider must be overridden by the app with its own '
    'NetworkConfig (baseUrl, timeouts) — see ProviderScope(overrides: ...) '
    'in the app entrypoint.',
  );
});

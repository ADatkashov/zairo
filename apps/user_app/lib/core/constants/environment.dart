import 'dart:io' show Platform;

import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// The app's own environment configuration — this is where a concrete
/// baseUrl is chosen, not inside core_network. Points at the local
/// backend (`backend/platform-api`, see infrastructure/docker-compose.yml)
/// since there's no deployed environment yet.
///
/// `--dart-define=API_BASE_URL=...` overrides everything below — set it to
/// e.g. `http://192.168.1.23:8080/api/v1` (your computer's LAN IP) to test
/// a release build on a physical device over Wi-Fi, since a real phone
/// can't resolve `localhost` or the Android-emulator-only `10.0.2.2` alias
/// to your computer. Include the `/api/v1` suffix — this value is used
/// as-is, unlike the auto-detected default below.
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// `localhost` only resolves to the host machine on web/desktop/iOS
/// simulator — the Android emulator's `localhost` is the emulator itself,
/// so it needs the documented alias `10.0.2.2` instead. Only reached when
/// [_apiBaseUrlOverride] above is empty (the default for local emulator/
/// simulator development).
String get _localBackendHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

NetworkConfig get appNetworkConfig => NetworkConfig(
      baseUrl: _apiBaseUrlOverride.isNotEmpty
          ? _apiBaseUrlOverride
          : 'http://$_localBackendHost:8080/api/v1',
    );

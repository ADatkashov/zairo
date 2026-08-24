import 'dart:io' show Platform;

import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// The app's own environment configuration — this is where a concrete
/// baseUrl is chosen, not inside core_network. Points at the local
/// backend (`backend/platform-api`, see infrastructure/docker-compose.yml)
/// since there's no deployed environment yet. Swap this out per flavor
/// (dev/staging/prod, via --dart-define or Flutter flavors) once a real
/// deployment exists to point at.
///
/// `localhost` only resolves to the host machine on web/desktop/iOS
/// simulator — the Android emulator's `localhost` is the emulator itself,
/// so it needs the documented alias `10.0.2.2` instead. A physical device
/// needs the host's real LAN IP, which isn't knowable here — override
/// [appNetworkConfig] at run time for that case.
String get _localBackendHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

NetworkConfig get appNetworkConfig => NetworkConfig(
      baseUrl: 'http://$_localBackendHost:8080/api/v1',
    );

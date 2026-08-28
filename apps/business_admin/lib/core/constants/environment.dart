import 'dart:io' show Platform;

import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Same local backend as apps/user_app — there's no deployed environment
/// yet. See apps/user_app/lib/core/constants/environment.dart for the
/// identical reasoning (including the Android-emulator `10.0.2.2` host
/// swap and the `--dart-define=API_BASE_URL=...` override for testing a
/// release build on a physical device); kept as a separate constant per
/// app rather than shared, so each app's environment can diverge
/// independently later (e.g. Business Admin pointed at a staging API
/// before the consumer app).
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

String get _localBackendHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

NetworkConfig get adminNetworkConfig => NetworkConfig(
      baseUrl: _apiBaseUrlOverride.isNotEmpty
          ? _apiBaseUrlOverride
          : 'http://$_localBackendHost:8080/api/v1',
    );

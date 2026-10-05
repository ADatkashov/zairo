import 'dart:io' show Platform;

import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// `--dart-define=API_BASE_URL=https://api.example.com/api/v1` points the
/// console at a deployed backend (this is how the web build is configured);
/// without it the console talks to a local backend, with the Android
/// emulator's `10.0.2.2` host swap. Same convention as the other apps, kept
/// as its own constant so the console can be pointed at a different
/// environment than they are.
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

String get _localBackendHost {
  if (kIsWeb) return 'localhost';
  if (Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

NetworkConfig get platformNetworkConfig => NetworkConfig(
  baseUrl: _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : 'http://$_localBackendHost:8080/api/v1',
);

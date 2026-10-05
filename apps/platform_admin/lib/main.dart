import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [networkConfigProvider.overrideWithValue(platformNetworkConfig)],
      child: const PlatformAdminApp(),
    ),
  );
}

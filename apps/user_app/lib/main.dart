import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_network/core_network.dart';
import 'app/app.dart';
import 'core/constants/environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        networkConfigProvider.overrideWithValue(appNetworkConfig),
      ],
      child: const ZairoApp(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_network/core_network.dart';
import 'app/app.dart';
import 'core/constants/environment.dart';
import 'features/maps/data/location_service.dart';
import 'features/maps/presentation/providers/maps_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [
        networkConfigProvider.overrideWithValue(appNetworkConfig),
        locationServiceProvider.overrideWithValue(DeviceLocationService()),
      ],
      child: const ZairoApp(),
    ),
  );
}

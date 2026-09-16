import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/automation_api.dart';
import '../../data/models/automation_settings.dart';

final automationApiProvider = Provider<AutomationApi>((ref) {
  return AutomationApi(ref.watch(dioClientProvider));
});

final automationSettingsProvider = FutureProvider.autoDispose.family<AutomationSettings, String>((ref, providerId) {
  return ref.watch(automationApiProvider).fetchSettings(providerId);
});

import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../providers/city_providers.dart';

const cityOnboardingDoneKey = 'city_onboarding_done';

/// Wraps Home. On the very first launch, if the app could not work out the
/// user's city on its own (no account city, no location to find the nearest
/// one), it opens the city picker once instead of leaving Home on "location
/// unknown" and its feed unfiltered. The prompt is shown at most once: it is
/// remembered whether the user picked a city or backed out, and it is skipped
/// entirely whenever a city is already known or the lookup failed (offline) —
/// a failure is retried on the next launch rather than nagging.
class CityOnboardingGate extends ConsumerStatefulWidget {
  const CityOnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CityOnboardingGate> createState() => _CityOnboardingGateState();
}

class _CityOnboardingGateState extends ConsumerState<CityOnboardingGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      if (await storage.read(cityOnboardingDoneKey) != null) return;

      final city = await ref.read(userCurrentCityProvider.future);
      await storage.write(cityOnboardingDoneKey, '1');
      if (city != null || !mounted) return;
      context.push(AppRoutes.citySelection);
    } catch (_) {
      // Storage or network unavailable: no prompt now, try again next launch.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

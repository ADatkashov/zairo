import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../providers/city_providers.dart';

const cityOnboardingDoneKey = 'city_onboarding_done';
const welcomeDoneKey = 'welcome_done';

/// Wraps Home. On the very first launch, if the app could not work out the
/// user's city on its own (no account city, no location to find the nearest
/// one), it opens the city picker once instead of leaving Home on "location
/// unknown" and its feed unfiltered. The prompt is shown at most once: it is
/// remembered whether the user picked a city or backed out, and it is skipped
/// entirely whenever a city is already known or the lookup failed (offline) —
/// a failure is retried on the next launch rather than nagging.
///
/// With [showWelcome], the first launch also opens the three-page welcome
/// first (once, then it is remembered), and the city prompt follows it.
class CityOnboardingGate extends ConsumerStatefulWidget {
  const CityOnboardingGate({super.key, required this.child, this.showWelcome = false});

  final Widget child;

  /// Whether to show the welcome pages on the very first launch. Off by default
  /// so existing callers behave as before.
  final bool showWelcome;

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
      if (widget.showWelcome && await storage.read(welcomeDoneKey) == null) {
        // Remembered before it opens: shown at most once, even if the app is
        // closed mid-way.
        await storage.write(welcomeDoneKey, '1');
        // An install that already went through the city prompt is an existing
        // user who updated, not a first launch: they don't get the welcome.
        final existingUser = await storage.read(cityOnboardingDoneKey) != null;
        if (!existingUser) {
          if (!mounted) return;
          await context.push<void>(AppRoutes.welcome);
          if (!mounted) return;
        }
      }
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

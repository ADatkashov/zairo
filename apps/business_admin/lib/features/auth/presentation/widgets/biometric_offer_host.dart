import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import 'enable_biometric_prompt.dart';

/// Wraps the logged-in home and, right after an interactive sign-in, offers to
/// enable fingerprint/face unlock once. The login screens cannot do it
/// themselves: AuthGate disposes them the moment sign-in succeeds. A silent
/// session restore never requests the offer.
class BiometricOfferHost extends ConsumerStatefulWidget {
  const BiometricOfferHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricOfferHost> createState() => _BiometricOfferHostState();
}

class _BiometricOfferHostState extends ConsumerState<BiometricOfferHost> {
  @override
  void initState() {
    super.initState();
    // The offer is requested before this widget exists (sign-in -> AuthGate swap).
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfPending());
  }

  void _offerIfPending() {
    if (!mounted) return;
    if (ref.read(biometricOfferPendingProvider.notifier).take()) {
      maybeOfferEnableBiometric(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(biometricOfferPendingProvider, (previous, pending) {
      if (pending) WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfPending());
    });
    return widget.child;
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';

/// Pre-production only: while the server mocks SMS (OTP_MOCK_CODE), no text
/// message will arrive, so this tells the tester which code to type. Renders
/// nothing when SMS is real.
class SmsMockHint extends ConsumerWidget {
  const SmsMockHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(smsModeProvider).value;
    final code = mode?.mockCode;
    if (mode == null || !mode.mock || code == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
      child: Container(
        padding: const EdgeInsets.all(FactorySpacing.space3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(l10n.smsMockHint(code)),
      ),
    );
  }
}

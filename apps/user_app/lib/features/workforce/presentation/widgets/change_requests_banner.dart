import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/workforce_providers.dart';

/// Shown above the bookings list while the owner is waiting for the customer's choice; hidden otherwise.
class ChangeRequestsBanner extends ConsumerWidget {
  const ChangeRequestsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(changeRequestsProvider).value?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space3, FactorySpacing.space4, 0),
      child: FactoryCard(
        onTap: () => context.push(AppRoutes.changeRequests),
        child: Row(
          children: [
            Icon(Icons.event_busy_outlined, color: colors.warning),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(child: Text(l10n.changeRequestsBanner(count))),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

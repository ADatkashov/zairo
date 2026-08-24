import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../providers/moderation_providers.dart';

/// Shown by AuthGate instead of DashboardScreen when the logged-in user is
/// ADMIN. Every newly created salon starts PENDING (see backend's
/// ProviderController.create()) and stays invisible to search until an
/// admin approves it here — this is the only UI that can ever change that.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final pendingAsync = ref.watch(pendingProvidersProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l10n.moderationTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsButtonTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logOutTooltip,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return Center(
              child: FactoryEmptyState(
                icon: Icons.fact_check_outlined,
                title: l10n.moderationEmptyTitle,
                message: l10n.moderationEmptyMessage,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: providers.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _PendingSalonCard(
              provider: providers[index],
              onSuspend: () async {
                await ref
                    .read(salonAdminApiProvider)
                    .updateProviderStatus(providerId: providers[index].id, status: 'SUSPENDED');
                ref.invalidate(pendingProvidersProvider);
              },
              onApprove: () async {
                await ref
                    .read(salonAdminApiProvider)
                    .updateProviderStatus(providerId: providers[index].id, status: 'ACTIVE');
                ref.invalidate(pendingProvidersProvider);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorPendingSalonsLoadFailed,
              onRetry: () => ref.invalidate(pendingProvidersProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingSalonCard extends StatelessWidget {
  const _PendingSalonCard({required this.provider, required this.onSuspend, required this.onApprove});

  final AdminProvider provider;
  final VoidCallback onSuspend;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.name, style: textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space2),
                  FactoryBadge(label: _capitalize(provider.vertical)),
                ],
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onSuspend, child: Text(l10n.suspendButton)),
                FilledButton(onPressed: onApprove, child: Text(l10n.approveButton)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

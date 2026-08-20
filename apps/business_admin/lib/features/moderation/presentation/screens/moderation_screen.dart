import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/moderation_providers.dart';

/// Shown by AuthGate instead of DashboardScreen when the logged-in user is
/// ADMIN. Every newly created salon starts PENDING (see backend's
/// ProviderController.create()) and stays invisible to search until an
/// admin approves it here — this is the only UI that can ever change that.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salon moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(child: Text('No salons awaiting approval.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: providers
                .map((p) => Card(
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text(p.vertical),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await ref
                                    .read(salonAdminApiProvider)
                                    .updateProviderStatus(providerId: p.id, status: 'SUSPENDED');
                                ref.invalidate(pendingProvidersProvider);
                              },
                              child: const Text('Suspend'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(salonAdminApiProvider)
                                    .updateProviderStatus(providerId: p.id, status: 'ACTIVE');
                                ref.invalidate(pendingProvidersProvider);
                              },
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Failed to load pending salons: $error')),
      ),
    );
  }
}

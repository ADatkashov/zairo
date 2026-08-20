import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../../salon/presentation/screens/salon_detail_screen.dart';

/// Shown by AuthGate once logged in. Lists the salons this owner manages
/// (usually one, but nothing stops an owner running several) and lets them
/// create a new one. Vertical is fixed to 'beauty' when creating — the
/// only vertical with real admin screens (masters/portfolio) built so far;
/// a vertical picker becomes meaningful once a second vertical exists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      // AuthGate only renders this screen once logged in; a null user here
      // would mean a logout happened mid-frame. Nothing useful to show.
      return const SizedBox.shrink();
    }

    final providersAsync = ref.watch(myProvidersProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return _CreateSalonForm(ownerUserId: user.id);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...providers.map((provider) => Card(
                    child: ListTile(
                      title: Text(provider.name),
                      subtitle: Text('${provider.vertical} — ${provider.status}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SalonDetailScreen(provider: provider)),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add another salon'),
                onPressed: () => _openCreateSalonDialog(context, ref, user.id),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Failed to load your salons: $error')),
      ),
    );
  }

  Future<void> _openCreateSalonDialog(BuildContext context, WidgetRef ref, String ownerUserId) async {
    final nameController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add a salon'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Salon name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await ref.read(salonAdminApiProvider).createProvider(
                    ownerUserId: ownerUserId,
                    name: nameController.text.trim(),
                    vertical: 'beauty',
                  );
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) {
      ref.invalidate(myProvidersProvider(ownerUserId));
    }
  }
}

class _CreateSalonForm extends ConsumerStatefulWidget {
  final String ownerUserId;

  const _CreateSalonForm({required this.ownerUserId});

  @override
  ConsumerState<_CreateSalonForm> createState() => _CreateSalonFormState();
}

class _CreateSalonFormState extends ConsumerState<_CreateSalonForm> {
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('You have no salons yet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(labelText: 'Salon name'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create salon'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a salon name');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(salonAdminApiProvider).createProvider(
            ownerUserId: widget.ownerUserId,
            name: _nameController.text.trim(),
            vertical: 'beauty',
          );
      ref.invalidate(myProvidersProvider(widget.ownerUserId));
    } catch (e) {
      setState(() {
        _error = 'Failed to create salon: $e';
        _isSubmitting = false;
      });
    }
  }
}

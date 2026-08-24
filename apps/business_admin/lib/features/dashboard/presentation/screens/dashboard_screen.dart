import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../../salon/presentation/screens/salon_detail_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Shown by AuthGate once logged in. Lists the salons this owner manages
/// (usually one, but nothing stops an owner running several) and lets them
/// create a new one. Vertical is fixed to 'beauty' when creating — the
/// only vertical with real admin screens (masters/portfolio) built so far;
/// a vertical picker becomes meaningful once a second vertical exists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      // AuthGate only renders this screen once logged in; a null user here
      // would mean a logout happened mid-frame. Nothing useful to show.
      return const SizedBox.shrink();
    }

    final providersAsync = ref.watch(myProvidersProvider(user.id));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l10n.dashboardGreeting(user.displayName)),
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
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return _CreateSalonForm(ownerUserId: user.id);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: providers.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) {
              if (index == providers.length) {
                return OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addAnotherSalonButton),
                  onPressed: () => _openCreateSalonDialog(context, ref, user.id),
                );
              }
              final provider = providers[index];
              return _SalonCard(
                provider: provider,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SalonDetailScreen(provider: provider)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorSalonsLoadFailed,
              onRetry: () => ref.invalidate(myProvidersProvider(user.id)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateSalonDialog(BuildContext context, WidgetRef ref, String ownerUserId) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.addSalonDialogTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.salonNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancelButton)),
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
            child: Text(l10n.createButton),
          ),
        ],
      ),
    );
    if (created == true) {
      ref.invalidate(myProvidersProvider(ownerUserId));
    }
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({required this.provider, required this.onTap});

  final AdminProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: FactoryRadius.lgRadius,
        onTap: onTap,
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
                    const SizedBox(height: 4),
                    Text(_capitalize(provider.vertical), style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              FactoryBadge(label: _providerStatusLabel(l10n, provider.status), variant: _providerStatusVariant(provider.status)),
              const SizedBox(width: FactorySpacing.space2),
              Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

FactoryBadgeVariant _providerStatusVariant(String status) => switch (status) {
      'ACTIVE' => FactoryBadgeVariant.available,
      'PENDING' => FactoryBadgeVariant.limited,
      'SUSPENDED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

String _providerStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'ACTIVE' => l10n.providerStatusActive,
      'PENDING' => l10n.providerStatusPending,
      'SUSPENDED' => l10n.providerStatusSuspended,
      _ => _capitalize(status),
    };

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

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
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: colors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(Icons.storefront_outlined, size: 22, color: colors.textTertiary),
            ),
            const SizedBox(height: FactorySpacing.space4),
            Text(l10n.noSalonsYetTitle, style: textTheme.titleSmall),
            const SizedBox(height: FactorySpacing.space4),
            TextField(
              controller: _nameController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(labelText: l10n.salonNameLabel),
            ),
            const SizedBox(height: FactorySpacing.space4),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.createSalonButton),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = l10n.validationSalonNameRequired);
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
        _error = l10n.errorCreateSalonFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

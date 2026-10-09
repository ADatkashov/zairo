import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/automation_providers.dart';
import '_automation_settings_form.dart';

/// Automation Center's top-level destination -- unifies Smart Fill, Rebook
/// and Reactivation's per-business configuration in one screen. Resolves
/// which business is being managed exactly like [LoyaltyScreen]/
/// [CampaignCenterScreen] (this app's established shared-provider mechanism:
/// `myProvidersProvider(ownerUserId)` plus a chip picker for an owner with
/// more than one business, skipping straight to its settings for an owner
/// with exactly one).
class AutomationCenterScreen extends ConsumerStatefulWidget {
  final String ownerUserId;

  const AutomationCenterScreen({super.key, required this.ownerUserId});

  @override
  ConsumerState<AutomationCenterScreen> createState() => _AutomationCenterScreenState();
}

class _AutomationCenterScreenState extends ConsumerState<AutomationCenterScreen> {
  String? _providerId;

  void _selectProvider(String providerId) {
    if (providerId == _providerId) return;
    setState(() => _providerId = providerId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final providersAsync = ref.watch(myProvidersProvider(widget.ownerUserId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.automationCenterScreenTitle),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space6),
                child: Text(
                  l10n.automationCenterNoBusinesses,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                ),
              ),
            );
          }
          if (_providerId == null || !providers.any((p) => p.id == _providerId)) {
            _providerId = providers.first.id;
          }
          return _AutomationCenterBody(
            providerId: _providerId!,
            providers: providers,
            onSelectProvider: _selectProvider,
          );
        },
        loading: () => const FactoryLoadingState(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorBusinessesLoadFailed,
              onRetry: () => ref.invalidate(myProvidersProvider(widget.ownerUserId)),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomationCenterBody extends ConsumerWidget {
  final String providerId;
  final List<AdminProvider> providers;
  final ValueChanged<String> onSelectProvider;

  const _AutomationCenterBody({required this.providerId, required this.providers, required this.onSelectProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(automationSettingsProvider(providerId));

    return Column(
      children: [
        if (providers.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FactorySpacing.space4,
              FactorySpacing.space3,
              FactorySpacing.space4,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final provider in providers)
                    FactoryChip(
                      label: provider.name,
                      selected: provider.id == providerId,
                      onTap: () => onSelectProvider(provider.id),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: settingsAsync.when(
            data: (settings) => AutomationSettingsForm(providerId: providerId, settings: settings),
            loading: () => const FactoryLoadingState(),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: FactoryErrorState(
                  message: l10n.errorAutomationSettingsLoadFailed,
                  onRetry: () => ref.invalidate(automationSettingsProvider(providerId)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

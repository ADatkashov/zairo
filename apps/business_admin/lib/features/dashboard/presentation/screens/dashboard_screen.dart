import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/formatting/vertical_label.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/change_avatar_dialog.dart';
import '../../../auth/presentation/widgets/confirm_log_out.dart';
import '../../../automation/presentation/screens/automation_center_screen.dart';
import '../../../billing/data/billing_exception.dart';
import '../../../billing/data/models/subscription.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../billing/presentation/screens/billing_screen.dart';
import '../../../campaigns/data/models/campaign.dart';
import '../../../campaigns/presentation/providers/campaign_providers.dart';
import '../../../campaigns/presentation/screens/campaign_center_screen.dart';
import '../../../catalog/presentation/category_icon.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../city/presentation/providers/city_providers.dart';
import '../../../loyalty/presentation/screens/loyalty_screen.dart';
import '../../../messaging/presentation/screens/business_inbox_screen.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../../salon/presentation/screens/week_calendar_screen.dart';
import '../../../salon/presentation/widgets/agenda_row.dart';
import '../../../salon/presentation/screens/customer_list_screen.dart';
import '../../../salon/presentation/screens/salon_detail_screen.dart';
import '../../../salon/presentation/widgets/add_service_dialog.dart';
import '../../../salon/presentation/widgets/recurring_schedule_dialog.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Shown by AuthGate once logged in. Lists the salons/workshops/cleaning
/// companies this owner manages (usually one, but nothing stops an owner
/// running several) and lets them create a new one, picking which category
/// it belongs to — Core's Provider.vertical is opaque free text, and the
/// picker itself is sourced from the master catalog (see catalog_providers)
/// so a platform admin adding a new category shows up here immediately,
/// with no app release. Beauty/auto/cleaning remain the only categories
/// with real staff-management screens built so far (see SalonDetailScreen).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.showNavActions = true});

  /// The AppBar shortcuts to Campaigns / Automation / Loyalty / Messages /
  /// Settings. The app shells (sidebar, bottom bar) already offer every one
  /// of those destinations, so they pass false and only the avatar and the
  /// log-out action remain.
  final bool showNavActions;

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
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: l10n.dashboardGreeting(user.displayName),
        leading: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space2),
          child: Semantics(
            button: true,
            label: l10n.changeAvatarDialogTitle,
            child: GestureDetector(
              onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: user.avatarUrl != null),
              child: FactoryAvatar(
                initials: _initialsFor(user.displayName),
                size: 32,
                image: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              ),
            ),
          ),
        ),
        actions: [
          if (showNavActions) ...[
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: l10n.campaignCenterNavLabel,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CampaignCenterScreen(ownerUserId: user.id)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bolt_outlined),
              tooltip: l10n.automationCenterNavLabel,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AutomationCenterScreen(ownerUserId: user.id)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.loyalty_outlined),
              tooltip: l10n.loyaltyNavLabel,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LoyaltyScreen(ownerUserId: user.id)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: l10n.messagingNavLabel,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BusinessInboxScreen(ownerUserId: user.id)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settingsButtonTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logOutTooltip,
            onPressed: () async {
              if (await confirmLogOut(context)) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return _CreateSalonForm(ownerUserId: user.id);
          }
          return RefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(myProvidersProvider(user.id).future),
              ref.refresh(mySubscriptionProvider.future),
            ]),
            child: ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: providers.length + 5,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _OwnerOverviewHero(ownerUserId: user.id);
              }
              if (index == 1) {
                return _NeedsAttentionStrip(
                  ownerUserId: user.id,
                  subscription: subscriptionAsync.value,
                );
              }
              if (index == 2) {
                return _TodayAgenda(ownerUserId: user.id);
              }
              if (index == 3) {
                return _QuickActions(providers: providers);
              }
              if (index == providers.length + 4) {
                final subscription = subscriptionAsync.value;
                final atLimit = subscription != null && providers.length >= subscription.limits.maxProviders;
                if (atLimit) {
                  return _ProviderLimitReachedNotice(subscription: subscription);
                }
                return FactoryButton(
                  icon: Icons.add,
                  label: l10n.addAnotherBusinessButton,
                  variant: FactoryButtonVariant.secondary,
                  onPressed: () => _openCreateSalonDialog(context, ref, user.id),
                );
              }
              final provider = providers[index - 4];
              return _SalonCard(
                provider: provider,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SalonDetailScreen(provider: provider)),
                ),
              );
            },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorBusinessesLoadFailed,
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
    String vertical = 'beauty';
    String? selectedCity;
    final created = await showFactoryDialog<bool>(
      context: context,
      title: l10n.addBusinessDialogTitle,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final citiesAsync = ref.watch(activeCitiesProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryTextField(
                controller: nameController,
                label: l10n.businessNameLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _CategoryPicker(
                value: vertical,
                onChanged: (v) => setDialogState(() => vertical = v),
              ),
              const SizedBox(height: FactorySpacing.space3),
              citiesAsync.when(
                data: (cities) {
                  if (cities.isEmpty) {
                    return Text(l10n.noCitiesAvailable);
                  }
                  if (selectedCity == null && cities.isNotEmpty) {
                    selectedCity = cities.first.code;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: selectedCity,
                    decoration: InputDecoration(
                      labelText: l10n.selectCity,
                      border: const OutlineInputBorder(),
                    ),
                    items: cities
                        .map((city) => DropdownMenuItem(
                              value: city.code,
                              child: Text(city.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCity = value);
                      }
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text(l10n.errorLoadingCities),
              ),
            ],
          );
        },
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        Builder(
          builder: (context) => FactoryButton(
            label: l10n.createButton,
            onPressed: () async {
              if (nameController.text.trim().isEmpty || selectedCity == null) return;
              try {
                await ref.read(salonAdminApiProvider).createProvider(
                      ownerUserId: ownerUserId,
                      name: nameController.text.trim(),
                      vertical: vertical,
                      cityCode: selectedCity!,
                    );
                if (context.mounted) Navigator.of(context).pop(true);
              } on BillingException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
                }
              }
            },
          ),
        ),
      ],
    );
    if (created == true) {
      ref.invalidate(myProvidersProvider(ownerUserId));
    }
  }
}

/// Gradient overview card summing [DashboardMetrics] across every business
/// this owner manages — Business Admin Redesign board (2026-09-05). Same
/// `primaryStrong` → `mint` diagonal treatment as the customer app's Home
/// availability hero (see user_app's `_AvailabilityHero`): the design
/// system's gradient case, reserved for one hero moment per app rather than
/// used as a general card style.
class _OwnerOverviewHero extends ConsumerWidget {
  const _OwnerOverviewHero({required this.ownerUserId});

  final String ownerUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(ownerOverviewProvider(ownerUserId));
    final overview = overviewAsync.value;
    // No data yet (still loading, or the fetch failed) — the businesses
    // list below still renders regardless, so this simply omits itself
    // rather than showing a loading/error placeholder for a purely
    // supplementary summary.
    if (overview == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    final secondaryStyle = textTheme.headlineSmall?.copyWith(color: colors.onPrimary);

    // Bento hero: revenue is the one big number, the rest are secondary.
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(FactorySpacing.space6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.primary],
        ),
        borderRadius: radius,
        boxShadow: context.factoryElevation(FactoryElevationLevel.lg),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Ambient glow: radial fade, not a flat disc.
                gradient: RadialGradient(
                  colors: [colors.accent.withValues(alpha: 0.42), colors.accent.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboardTotalRevenueLabel,
                style: textTheme.labelMedium?.copyWith(color: colors.onPrimary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: FactorySpacing.space1),
              FactoryPriceText(
                amount: overview.totalRevenue,
                currencySymbol: overview.currency,
                fontSize: 40,
                color: colors.onPrimary,
              ),
              const SizedBox(height: FactorySpacing.space5),
              Wrap(
                spacing: FactorySpacing.space8,
                runSpacing: FactorySpacing.space3,
                children: [
                  _OverviewStat(
                    value: Text('${overview.totalBookings}', style: secondaryStyle),
                    label: l10n.dashboardTotalBookingsLabel,
                  ),
                  _OverviewStat(
                    value: Text('${overview.totalCustomers}', style: secondaryStyle),
                    label: l10n.dashboardTotalCustomersLabel,
                  ),
                  _OverviewStat(
                    value: Text('${overview.businessCount}', style: secondaryStyle),
                    label: l10n.dashboardBusinessesCountLabel,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.value, required this.label});

  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.factoryColors.onPrimary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Board 12 (v2 design audit) — the dashboard's central principle: "tell
/// the business owner what needs attention and what action can generate
/// value" instead of just totals. Both sources here are real and were
/// already fully built server-side but never surfaced anywhere:
/// [Subscription.gracePeriodEndsAt]/status (see BillingScreen's grace-period
/// banner) and [ownerSmartActionsProvider] (Campaign Center's smart-actions
/// endpoint, previously fetched by no screen at all).
class _NeedsAttentionStrip extends ConsumerWidget {
  const _NeedsAttentionStrip({required this.ownerUserId, required this.subscription});

  final String ownerUserId;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final actionsAsync = ref.watch(ownerSmartActionsProvider(ownerUserId));
    final actions = actionsAsync.value ?? const <SmartActionItem>[];

    final countsByType = <SmartActionType, int>{};
    for (final action in actions) {
      countsByType[action.type] = (countsByType[action.type] ?? 0) + 1;
    }

    void openCampaignCenter() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CampaignCenterScreen(ownerUserId: ownerUserId)),
        );

    final items = <_AttentionItem>[
      if (subscription?.status == 'PAST_DUE')
        _AttentionItem(
          icon: Icons.warning_amber_rounded,
          label: l10n.dashboardAttentionBillingPastDue,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BillingScreen()),
          ),
        ),
      // A fixed, priority-ish order (expiring/failed campaigns first, then
      // customer-growth opportunities) rather than sorted by raw count —
      // one urgent expiring campaign matters more than five long-inactive
      // customers that have waited months already.
      for (final type in SmartActionType.values)
        if (countsByType[type] != null)
          _AttentionItem(
            icon: _smartActionIcon(type),
            label: _smartActionLabel(l10n, type, countsByType[type]!),
            onTap: openCampaignCenter,
          ),
    ];

    if (items.isEmpty) {
      // Still loading (actionsAsync not settled) shows nothing rather than
      // a premature "all clear" that would flicker away once data arrives.
      if (!actionsAsync.hasValue && subscription == null) {
        return const SizedBox.shrink();
      }
      return Text(
        l10n.dashboardAttentionAllClear,
        style: textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dashboardNeedsAttentionTitle, style: textTheme.titleSmall),
        const SizedBox(height: FactorySpacing.space2),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
            child: _AttentionCard(item: item),
          ),
      ],
    );
  }
}

class _AttentionItem {
  const _AttentionItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return FactoryCard(
      onTap: item.onTap,
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: colors.warning),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Text(item.label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
      ),
    );
  }
}

IconData _smartActionIcon(SmartActionType type) => switch (type) {
      SmartActionType.campaignExpiringSoon => Icons.hourglass_bottom_rounded,
      SmartActionType.failedCampaign => Icons.error_outline_rounded,
      SmartActionType.retriableCampaign => Icons.replay_rounded,
      SmartActionType.rebookingOpportunity => Icons.event_repeat_rounded,
      SmartActionType.atRiskCustomer => Icons.person_off_outlined,
      SmartActionType.longInactiveCustomer => Icons.person_search_outlined,
    };

String _smartActionLabel(AppLocalizations l10n, SmartActionType type, int count) => switch (type) {
      SmartActionType.campaignExpiringSoon => l10n.dashboardAttentionCampaignExpiringSoon(count),
      SmartActionType.failedCampaign => l10n.dashboardAttentionFailedCampaign(count),
      SmartActionType.retriableCampaign => l10n.dashboardAttentionRetriableCampaign(count),
      SmartActionType.rebookingOpportunity => l10n.dashboardAttentionRebookingOpportunity(count),
      SmartActionType.atRiskCustomer => l10n.dashboardAttentionAtRiskCustomer(count),
      SmartActionType.longInactiveCustomer => l10n.dashboardAttentionLongInactiveCustomer(count),
    };

/// Replaces the old 3-option `SegmentedButton` (beauty/auto/cleaning) with a
/// dropdown sourced from the master catalog — a `SegmentedButton` doesn't
/// scale to 20+ admin-managed categories, a dropdown does. `value`/`onChanged`
/// carry the category's `code` (unchanged contract: still what's sent as
/// `Provider.vertical`).
class _CategoryPicker extends ConsumerWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categoriesAsync = ref.watch(categoriesProvider);
    final languageCode = Localizations.localeOf(context).languageCode;

    return categoriesAsync.when(
      data: (categories) {
        // Fall back to a plain text field if a caller's `value` (e.g. the
        // '"beauty"' default) isn't in the fetched list for some reason,
        // rather than crashing DropdownButtonFormField on an unmatched value.
        final hasValue = categories.any((c) => c.code == value);
        return DropdownButtonFormField<String>(
          initialValue: hasValue ? value : null,
          decoration: InputDecoration(labelText: l10n.businessCategoryLabel),
          items: [
            for (final category in categories)
              DropdownMenuItem(value: category.code, child: Text(category.nameFor(languageCode))),
          ],
          onChanged: (code) {
            if (code != null) onChanged(code);
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(l10n.errorBusinessesLoadFailed),
    );
  }
}

class _ProviderLimitReachedNotice extends StatelessWidget {
  const _ProviderLimitReachedNotice({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactoryButton(
          icon: Icons.add,
          label: l10n.addAnotherBusinessButton,
          variant: FactoryButtonVariant.secondary,
          onPressed: null,
        ),
        const SizedBox(height: FactorySpacing.space2),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BillingScreen()),
            ),
            child: Text(
              l10n.providerLimitReachedUpgradePrompt(subscription.limits.maxProviders),
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
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

    final (categoryColor, categoryTint) = categoryAccentFor(colors, provider.vertical);

    return FactoryCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: categoryTint, borderRadius: FactoryRadius.mdRadius),
            child: Icon(iconForCategory(provider.vertical), size: 20, color: categoryColor),
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(provider.name, style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(verticalLabel(l10n, provider.vertical), style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          FactoryBadge(label: _providerStatusLabel(l10n, provider.status), variant: _providerStatusVariant(provider.status)),
          const SizedBox(width: FactorySpacing.space2),
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
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

/// Two things an owner does every day, one tap from the Dashboard instead of
/// Dashboard → business → section → add. With several businesses the owner is
/// asked which one first.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.providers});

  final List<AdminProvider> providers;

  Future<AdminProvider?> _pickBusiness(BuildContext context) async {
    if (providers.length == 1) return providers.first;
    final l10n = AppLocalizations.of(context)!;
    return showFactoryBottomSheet<AdminProvider>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, 0, FactorySpacing.space4, FactorySpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.quickActionPickBusiness, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space2),
            for (final provider in providers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(provider.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(sheetContext).pop(provider),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setSchedule(BuildContext context, WidgetRef ref) async {
    final provider = await _pickBusiness(context);
    if (provider == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context)!.quickActionSlotAdded;
    final added = await showDialog<bool>(context: context, builder: (_) => RecurringScheduleDialog(providerId: provider.id));
    if (added == true) {
      ref.invalidate(providerSlotsProvider(provider.id));
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _addService(BuildContext context, WidgetRef ref) async {
    final provider = await _pickBusiness(context);
    if (provider == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context)!.quickActionServiceAdded;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddServiceDialog(providerId: provider.id, businessTypeId: provider.businessTypeId),
    );
    if (added == true) {
      ref.invalidate(providerServicesProvider);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openCustomers(BuildContext context) async {
    final provider = await _pickBusiness(context);
    if (provider == null || !context.mounted) return;
    final title = AppLocalizations.of(context)!.quickActionCustomers;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CustomerListScreen(providerId: provider.id, title: title)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: FactorySpacing.space2,
      runSpacing: FactorySpacing.space2,
      children: [
        FactoryButton(
          icon: Icons.event_available_outlined,
          label: l10n.quickActionAddSlot,
          variant: FactoryButtonVariant.secondary,
          onPressed: () => _setSchedule(context, ref),
        ),
        FactoryButton(
          icon: Icons.add_business_outlined,
          label: l10n.quickActionAddService,
          variant: FactoryButtonVariant.secondary,
          onPressed: () => _addService(context, ref),
        ),
        FactoryButton(
          icon: Icons.groups_outlined,
          label: l10n.quickActionCustomers,
          variant: FactoryButtonVariant.secondary,
          onPressed: () => _openCustomers(context),
        ),
      ],
    );
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
  String _vertical = 'beauty';
  String? _cityCode;
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
    final citiesAsync = ref.watch(activeCitiesProvider);

    // Scrollable: with the keyboard open on a phone this form is taller than
    // the screen, and a bare Column overflowed instead of letting it scroll.
    return Center(
      child: SingleChildScrollView(
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
            Text(l10n.noBusinessesYetTitle, style: textTheme.titleSmall),
            const SizedBox(height: FactorySpacing.space4),
            FactoryTextField(
              controller: _nameController,
              enabled: !_isSubmitting,
              label: l10n.businessNameLabel,
            ),
            const SizedBox(height: FactorySpacing.space3),
            _CategoryPicker(
              value: _vertical,
              onChanged: _isSubmitting ? (_) {} : (v) => setState(() => _vertical = v),
            ),
            const SizedBox(height: FactorySpacing.space3),
            citiesAsync.when(
              data: (cities) {
                if (cities.isEmpty) return Text(l10n.noCitiesAvailable);
                return DropdownButtonFormField<String>(
                  initialValue: _cityCode ?? cities.first.code,
                  decoration: InputDecoration(
                    labelText: l10n.selectCity,
                    border: const OutlineInputBorder(),
                  ),
                  items: cities
                      .map((city) => DropdownMenuItem(value: city.code, child: Text(city.name)))
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _cityCode = value);
                        },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text(l10n.errorLoadingCities),
            ),
            const SizedBox(height: FactorySpacing.space4),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            FactoryButton(
              label: l10n.createBusinessButton,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = l10n.validationBusinessNameRequired);
      return;
    }
    final cityCode = _cityCode ?? ref.read(activeCitiesProvider).value?.firstOrNull?.code;
    if (cityCode == null) {
      setState(() => _error = l10n.noCitiesAvailable);
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
            vertical: _vertical,
            cityCode: cityCode,
          );
      ref.invalidate(myProvidersProvider(widget.ownerUserId));
    } catch (e) {
      setState(() {
        _error = e is BillingException ? e.localizedMessage(l10n) : l10n.errorCreateBusinessFailed;
        _isSubmitting = false;
      });
    }
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}


/// Today's bookings across the owner's businesses: time, service, status.
/// Shows the next few and says so plainly when there are none. While loading
/// or on error it stays out of the way (the rest of the dashboard still
/// works without it).
class _TodayAgenda extends ConsumerWidget {
  const _TodayAgenda({required this.ownerUserId});

  final String ownerUserId;

  static const int _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(ownerTodayAgendaProvider(ownerUserId)).value;
    if (agenda == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final multiple = agenda.map((a) => a.providerName).toSet().length > 1;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.dashboardAgendaTitle, style: textTheme.titleMedium)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WeekCalendarScreen(ownerUserId: ownerUserId)),
                ),
                child: Text(l10n.calendarTitle),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          if (agenda.isEmpty)
            Text(l10n.dashboardAgendaEmpty, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary))
          else
            for (final item in agenda.take(_maxRows))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
                child: AgendaRow(item: item, showProvider: multiple),
              ),
          if (agenda.length > _maxRows)
            Text(
              '+${agenda.length - _maxRows}',
              style: FactoryTypography.mono(size: 12, color: colors.textTertiary),
            ),
        ],
      ),
    );
  }
}

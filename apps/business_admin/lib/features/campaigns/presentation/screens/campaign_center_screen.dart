import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/models/campaign.dart';
import '../providers/campaign_providers.dart';
import '../widgets/campaign_card.dart';
import 'campaign_detail_screen.dart';

enum _DatePreset { allTime, today, thisWeek, thisMonth, custom }

/// Phase 7's main screen: KPI summary, filters, and the full campaign list
/// across every Smart Fill/Rebook/Reactivation campaign for one business --
/// a first-class top-level destination (see admin_shell.dart's sidebar and
/// DashboardScreen's AppBar action), not nested under [SalonDetailScreen]
/// like Business Analytics. The Campaign Center API is scoped to one
/// provider at a time, so an owner with more than one business picks which
/// one via [_ProviderPicker]; an owner with exactly one skips straight to
/// its campaigns.
class CampaignCenterScreen extends ConsumerStatefulWidget {
  final String ownerUserId;

  const CampaignCenterScreen({super.key, required this.ownerUserId});

  @override
  ConsumerState<CampaignCenterScreen> createState() => _CampaignCenterScreenState();
}

class _CampaignCenterScreenState extends ConsumerState<CampaignCenterScreen> {
  String? _providerId;
  CampaignFilters _filters = const CampaignFilters();
  _DatePreset _datePreset = _DatePreset.allTime;
  DateTimeRange? _customRange;
  int _page = 0;
  final List<CampaignDto> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPaging() {
    _page = 0;
    _items.clear();
    _loadedPages.clear();
    _totalPages = 1;
  }

  void _selectProvider(String providerId) {
    if (providerId == _providerId) return;
    setState(() {
      _providerId = providerId;
      _resetPaging();
    });
  }

  void _updateFilters(CampaignFilters filters) {
    setState(() {
      _filters = filters;
      _resetPaging();
    });
  }

  void _loadMore() {
    setState(() => _page += 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final providersAsync = ref.watch(myProvidersProvider(widget.ownerUserId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.campaignCenterScreenTitle),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space6),
                child: Text(
                  l10n.campaignCenterNoBusinesses,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                ),
              ),
            );
          }
          if (_providerId == null || !providers.any((p) => p.id == _providerId)) {
            _providerId = providers.first.id;
          }
          return _CampaignCenterBody(
            providerId: _providerId!,
            providers: providers,
            onSelectProvider: _selectProvider,
            filters: _filters,
            datePreset: _datePreset,
            customRange: _customRange,
            searchController: _searchController,
            onFiltersChanged: _updateFilters,
            onDatePresetChanged: (preset, range) => setState(() {
              _datePreset = preset;
              _customRange = range;
            }),
            page: _page,
            items: _items,
            totalPages: _totalPages,
            onPageArrived: (resp) {
              if (_loadedPages.add(resp.page)) {
                setState(() {
                  _items.addAll(resp.items);
                  _totalPages = resp.totalPages;
                });
              }
            },
            onLoadMore: _loadMore,
            onRefresh: () {
              ref.invalidate(campaignStatsProvider(_providerId!));
              setState(_resetPaging);
            },
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

class _CampaignCenterBody extends ConsumerWidget {
  final String providerId;
  final List<AdminProvider> providers;
  final ValueChanged<String> onSelectProvider;
  final CampaignFilters filters;
  final _DatePreset datePreset;
  final DateTimeRange? customRange;
  final TextEditingController searchController;
  final ValueChanged<CampaignFilters> onFiltersChanged;
  final void Function(_DatePreset, DateTimeRange?) onDatePresetChanged;
  final int page;
  final List<CampaignDto> items;
  final int totalPages;
  final ValueChanged<CampaignListResponse> onPageArrived;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  const _CampaignCenterBody({
    required this.providerId,
    required this.providers,
    required this.onSelectProvider,
    required this.filters,
    required this.datePreset,
    required this.customRange,
    required this.searchController,
    required this.onFiltersChanged,
    required this.onDatePresetChanged,
    required this.page,
    required this.items,
    required this.totalPages,
    required this.onPageArrived,
    required this.onLoadMore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (providerId, filters, page);
    final pageAsync = ref.watch(campaignListProvider(key));

    ref.listen(campaignListProvider(key), (previous, next) {
      next.whenData(onPageArrived);
    });

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          Text(
            l10n.campaignCenterSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: FactorySpacing.space4),
          if (providers.length > 1) ...[
            _ProviderPicker(providers: providers, selectedId: providerId, onSelect: onSelectProvider),
            const SizedBox(height: FactorySpacing.space4),
          ],
          _StatsRow(providerId: providerId),
          const SizedBox(height: FactorySpacing.space5),
          _FunnelSection(providerId: providerId),
          const SizedBox(height: FactorySpacing.space5),
          _FiltersSection(
            providerId: providerId,
            filters: filters,
            datePreset: datePreset,
            customRange: customRange,
            searchController: searchController,
            onFiltersChanged: onFiltersChanged,
            onDatePresetChanged: onDatePresetChanged,
          ),
          const SizedBox(height: FactorySpacing.space4),
          if (items.isEmpty)
            pageAsync.when(
              data: (resp) => resp.items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                      child: Center(
                        child: Text(
                          l10n.campaignListEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                      child: FactoryLoadingState(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                child: FactoryLoadingState(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
                child: FactoryErrorState(
                  message: l10n.errorCampaignsLoadFailed(error.toString()),
                  onRetry: () => ref.invalidate(campaignListProvider(key)),
                ),
              ),
            )
          else ...[
            for (final campaign in items) ...[
              CampaignCard(
                campaign: campaign,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CampaignDetailScreen(providerId: providerId, type: campaign.type, campaignId: campaign.id),
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
            ],
            if (page + 1 < totalPages)
              Center(
                child: pageAsync.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(FactorySpacing.space4),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : FactoryButton(
                        label: l10n.campaignListLoadMore,
                        variant: FactoryButtonVariant.secondary,
                        onPressed: onLoadMore,
                      ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  final List<AdminProvider> providers;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _ProviderPicker({required this.providers, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in providers)
          FactoryChip(label: provider.name, selected: provider.id == selectedId, onTap: () => onSelect(provider.id)),
      ],
    );
  }
}

class _StatsRow extends ConsumerWidget {
  final String providerId;

  const _StatsRow({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(campaignStatsProvider(providerId));

    return statsAsync.when(
      data: (stats) => Wrap(
        spacing: FactorySpacing.space3,
        runSpacing: FactorySpacing.space3,
        children: [
          FactoryStatTile(label: l10n.campaignKpiActive, value: '${stats.activeCampaigns}'),
          FactoryStatTile(
            label: l10n.campaignKpiRecoveredRevenue,
            value: '${formatFactoryAmount(stats.totalRecoveredRevenue)} ${stats.currency ?? ''}'.trim(),
          ),
          FactoryStatTile(label: l10n.campaignKpiConversionRate, value: '${(stats.conversionRate * 100).round()}%'),
          FactoryStatTile(label: l10n.campaignKpiNeedsAttention, value: '${stats.campaignsRequiringAttention}'),
        ],
      ),
      loading: () => const FactoryLoadingState(),
      error: (error, _) => FactoryErrorState(
        message: l10n.errorCampaignStatsLoadFailed(error.toString()),
        onRetry: () => ref.invalidate(campaignStatsProvider(providerId)),
      ),
    );
  }
}

/// Board 13 (v2 design audit) — the funnel the brief asked for was
/// Audience→Campaign→Offer→Sent→Opened→Booked→Revenue; only four of those
/// stages are backend-real (see [CampaignStatsResponse]): the platform
/// never records a distinct "audience size" separate from campaigns
/// started (each campaign already targets one customer), and there is no
/// notification open/read receipt anywhere in the notifications module.
/// This renders exactly the four stages the API returns, not a fabricated
/// seven.
class _FunnelSection extends ConsumerWidget {
  final String providerId;

  const _FunnelSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(campaignStatsProvider(providerId));
    final stats = statsAsync.value;
    if (stats == null) return const SizedBox.shrink();

    final totalCampaigns = stats.activeCampaigns +
        stats.completedCampaigns +
        stats.failedCampaigns +
        stats.expiredCampaigns +
        stats.cancelledCampaigns;
    final maxCount = [totalCampaigns, stats.notificationsSent, stats.offersAccepted]
        .fold(0, (max, v) => v > max ? v : max);

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.campaignFunnelTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: FactorySpacing.space3),
          _FunnelStage(label: l10n.campaignFunnelStageCampaigns, count: totalCampaigns, maxCount: maxCount),
          const SizedBox(height: FactorySpacing.space2),
          _FunnelStage(label: l10n.campaignFunnelStageSent, count: stats.notificationsSent, maxCount: maxCount),
          const SizedBox(height: FactorySpacing.space2),
          _FunnelStage(label: l10n.campaignFunnelStageBooked, count: stats.offersAccepted, maxCount: maxCount),
          const SizedBox(height: FactorySpacing.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.campaignFunnelStageRevenue, style: Theme.of(context).textTheme.bodyMedium),
              FactoryPriceText(
                amount: stats.totalRecoveredRevenue,
                currencySymbol: stats.currency,
                fontSize: 15,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FunnelStage extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;

  const _FunnelStage({required this.label, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
        ),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.04, 1.0),
            child: Container(
              height: 20,
              decoration: BoxDecoration(color: colors.primary, borderRadius: FactoryRadius.smRadius),
            ),
          ),
        ),
        const SizedBox(width: FactorySpacing.space2),
        SizedBox(
          width: 36,
          child: Text('$count', textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _FiltersSection extends ConsumerWidget {
  final String providerId;
  final CampaignFilters filters;
  final _DatePreset datePreset;
  final DateTimeRange? customRange;
  final TextEditingController searchController;
  final ValueChanged<CampaignFilters> onFiltersChanged;
  final void Function(_DatePreset, DateTimeRange?) onDatePresetChanged;

  const _FiltersSection({
    required this.providerId,
    required this.filters,
    required this.datePreset,
    required this.customRange,
    required this.searchController,
    required this.onFiltersChanged,
    required this.onDatePresetChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final servicesAsync = ref.watch(providerServicesProvider((providerId, false)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySearchField(
          controller: searchController,
          hint: l10n.campaignFilterSearchHint,
          onSubmitted: (value) => onFiltersChanged(filters.copyWith(search: value.trim(), clearSearch: value.trim().isEmpty)),
        ),
        const SizedBox(height: FactorySpacing.space3),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FactoryChip(
              label: l10n.campaignFilterStatusAll,
              selected: filters.status == null,
              onTap: () => onFiltersChanged(filters.copyWith(clearStatus: true)),
            ),
            for (final status in const [
              CampaignStatus.active,
              CampaignStatus.completed,
              CampaignStatus.failed,
              CampaignStatus.expired,
            ])
              FactoryChip(
                label: campaignStatusLabel(l10n, status),
                selected: filters.status == status,
                onTap: () => onFiltersChanged(filters.copyWith(status: status)),
              ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FactoryChip(
              label: l10n.campaignFilterTypeAll,
              selected: filters.type == null,
              onTap: () => onFiltersChanged(filters.copyWith(clearType: true)),
            ),
            for (final type in CampaignType.values)
              FactoryChip(
                label: campaignTypeLabel(l10n, type),
                selected: filters.type == type,
                onTap: () => onFiltersChanged(filters.copyWith(type: type)),
              ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FactoryChip(
              label: l10n.campaignFilterDateAll,
              selected: datePreset == _DatePreset.allTime,
              onTap: () {
                onDatePresetChanged(_DatePreset.allTime, null);
                onFiltersChanged(filters.copyWith(clearRange: true));
              },
            ),
            FactoryChip(
              label: l10n.analyticsPeriodToday,
              selected: datePreset == _DatePreset.today,
              onTap: () => _applyPreset(context, _DatePreset.today),
            ),
            FactoryChip(
              label: l10n.analyticsPeriodThisWeek,
              selected: datePreset == _DatePreset.thisWeek,
              onTap: () => _applyPreset(context, _DatePreset.thisWeek),
            ),
            FactoryChip(
              label: l10n.analyticsPeriodThisMonth,
              selected: datePreset == _DatePreset.thisMonth,
              onTap: () => _applyPreset(context, _DatePreset.thisMonth),
            ),
            FactoryChip(
              label: datePreset == _DatePreset.custom && customRange != null
                  ? '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(customRange!.start)} – '
                      '${DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(customRange!.end)}'
                  : l10n.analyticsPeriodCustom,
              selected: datePreset == _DatePreset.custom,
              icon: Icons.calendar_month_outlined,
              onTap: () => _pickCustomRange(context),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space2),
        servicesAsync.maybeWhen(
          data: (services) => services.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FactoryChip(
                      label: l10n.campaignFilterServiceAll,
                      selected: filters.serviceId == null,
                      onTap: () => onFiltersChanged(filters.copyWith(clearServiceId: true)),
                    ),
                    for (final service in services)
                      FactoryChip(
                        label: service.title,
                        selected: filters.serviceId == service.id,
                        onTap: () => onFiltersChanged(filters.copyWith(serviceId: service.id)),
                      ),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  (DateTime, DateTime) _rangeFor(_DatePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case _DatePreset.allTime:
      case _DatePreset.custom:
        return (now, now);
      case _DatePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case _DatePreset.thisWeek:
        final todayStart = DateTime(now.year, now.month, now.day);
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return (weekStart, weekStart.add(const Duration(days: 7)));
      case _DatePreset.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return (monthStart, nextMonth);
    }
  }

  void _applyPreset(BuildContext context, _DatePreset preset) {
    onDatePresetChanged(preset, null);
    final (from, to) = _rangeFor(preset);
    onFiltersChanged(filters.copyWith(from: from, to: to));
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked == null) return;
    onDatePresetChanged(_DatePreset.custom, picked);
    // showDateRangePicker's end is inclusive of that whole day; the API's [from, to) is exclusive.
    onFiltersChanged(filters.copyWith(from: picked.start, to: picked.end.add(const Duration(days: 1))));
  }
}

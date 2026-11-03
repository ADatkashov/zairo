import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/csv.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../finance/data/finance_api.dart';
import '../data/business.dart';
import '../data/business_api.dart';
import '../data/saved_views.dart';
import 'businesses_table.dart';

/// Every business on the platform. Businesses waiting for approval come
/// first, with a banner that filters down to them; the rest can be searched by
/// name and filtered by status. Tapping a business opens its details —
/// including what it is owed — with the actions its role allows.
class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key, this.initialStatus});

  /// A deep link such as `/businesses?status=PENDING` opens pre-filtered.
  final String? initialStatus;

  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends ConsumerState<BusinessesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _status;
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _status = const {'PENDING', 'ACTIVE', 'SUSPENDED'}.contains(widget.initialStatus) ? widget.initialStatus : null;
  }

  @override
  void didUpdateWidget(covariant BusinessesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tapping "Review" on the dashboard while this screen is already alive.
    if (widget.initialStatus != oldWidget.initialStatus) {
      setState(
        () => _status = const {'PENDING', 'ACTIVE', 'SUSPENDED'}.contains(widget.initialStatus)
            ? widget.initialStatus
            : null,
      );
    }
  }

  /// Applies [next] to every selected business it would change. Suspending
  /// asks once (with one optional reason for all of them); each business is a
  /// separate request, so a partial failure is reported with the counts and
  /// the failed rows stay selected for a retry.
  Future<void> _bulk(List<Business> targets, String next) async {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(businessApiProvider);
    final eligible = targets.where((b) => b.status != next).toList();
    if (eligible.isEmpty) return;

    String? reason;
    if (next == 'SUSPENDED') {
      reason = await promptText(
        context,
        title: l10n.bulkSuspendTitle(eligible.length),
        message: l10n.suspendMessage,
        fieldLabel: l10n.reasonOptional,
        confirmLabel: l10n.suspend,
        destructive: true,
      );
      if (reason == null) return;
    }
    if (!mounted) return;

    setState(() => _bulkBusy = true);
    final failed = <String>{};
    for (final business in eligible) {
      try {
        await api.setStatus(business.id, next, reason: (reason == null || reason.isEmpty) ? null : reason);
      } catch (_) {
        failed.add(business.id);
      }
    }
    ref.invalidate(businessesProvider);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selected
        ..clear()
        ..addAll(failed);
    });
    showSnack(
      context,
      failed.isEmpty
          ? l10n.bulkDone(eligible.length)
          : l10n.bulkPartial(eligible.length - failed.length, failed.length),
    );
  }

  BusinessSortColumn? _sortColumn;
  bool _sortAscending = true;

  /// The rows currently on screen (after search and status filter), for "Copy as CSV".
  List<Business> _visible = const [];

  /// Puts what is on screen on the clipboard as CSV: paste it straight into a spreadsheet.
  Future<void> _copyCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final csv = toCsv(
      const ['id', 'name', 'vertical', 'status', 'registered'],
      [
        for (final b in _visible)
          [b.id, b.name, b.vertical, b.status, b.createdAt?.toUtc().toIso8601String() ?? ''],
      ],
    );
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) showSnack(context, l10n.businessesCsvCopied(_visible.length));
  }

  /// Explicit column sort when chosen; otherwise pending businesses first
  /// (they need a decision), then by name.
  int _comparator(Business a, Business b) {
    int byName() => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final column = _sortColumn;
    if (column == null) {
      final byPending = (b.status == 'PENDING' ? 1 : 0) - (a.status == 'PENDING' ? 1 : 0);
      return byPending != 0 ? byPending : byName();
    }
    final direction = _sortAscending ? 1 : -1;
    switch (column) {
      case BusinessSortColumn.name:
        return direction * byName();
      case BusinessSortColumn.registered:
        final da = a.createdAt, db = b.createdAt;
        // Businesses with no date sort last whichever way the column runs.
        if (da == null || db == null) return da == db ? byName() : (da == null ? 1 : -1);
        final c = da.compareTo(db);
        return c != 0 ? direction * c : byName();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(businessesProvider);
    final canModerate = ref.watch(permissionsProvider).canModerateBusinesses;
    Future<void> refresh() => ref.refresh(businessesProvider.future);

    return AreaScaffold(
      title: l10n.navBusinesses,
      actions: [
        if (async.hasValue)
          IconButton(
            tooltip: l10n.businessesCopyCsv,
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: _copyCsv,
          ),
        IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh),
      ],
      body: AsyncView<List<Business>>(
        value: async,
        onRetry: () => ref.invalidate(businessesProvider),
        builder: (businesses) {
          if (businesses.isEmpty) {
            return EmptyView(
              icon: Icons.storefront_outlined,
              title: l10n.businessesEmptyTitle,
              message: l10n.businessesEmptyMessage,
              onRefresh: refresh,
            );
          }
          final pending = businesses.where((b) => b.status == 'PENDING').length;
          final needle = _query.trim().toLowerCase();
          final visible = businesses.where((b) {
            if (_status != null && b.status != _status) return false;
            return needle.isEmpty || b.name.toLowerCase().contains(needle);
          }).toList()..sort(_comparator);

          _visible = visible;

          // Only rows still on screen stay selected (a filter or a refresh
          // can hide them), so a bulk action never touches unseen rows.
          final selectedBusinesses = visible.where((b) => _selected.contains(b.id)).toList();

          return ContentFrame(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  if (pending > 0 && _status != 'PENDING') ...[
                    _PendingBanner(count: pending, onShow: () => setState(() => _status = 'PENDING')),
                    const SizedBox(height: FactorySpacing.space3),
                  ],
                  FactorySearchField(
                    controller: _search,
                    hint: l10n.businessesSearchHint,
                    onChanged: (value) => setState(() => _query = value),
                    onCleared: () => setState(() => _query = ''),
                    clearSemanticLabel: l10n.clear,
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  _StatusTabs(
                    selected: _status,
                    counts: {
                      null: businesses.length,
                      for (final status in const ['PENDING', 'ACTIVE', 'SUSPENDED'])
                        status: businesses.where((b) => b.status == status).length,
                    },
                    onSelect: (status) => setState(() {
                      _status = status;
                      _selected.clear();
                    }),
                  ),
                  _SavedViewsRow(
                    status: _status,
                    query: _query,
                    onApply: (v) => setState(() {
                      _status = v.status;
                      _query = v.query;
                      _search.text = v.query;
                      _selected.clear();
                    }),
                  ),
                  if (selectedBusinesses.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.space3),
                    _BulkBar(
                      count: selectedBusinesses.length,
                      busy: _bulkBusy,
                      canApprove: selectedBusinesses.any((b) => b.status != 'ACTIVE'),
                      canSuspend: selectedBusinesses.any((b) => b.status != 'SUSPENDED'),
                      onApprove: () => _bulk(selectedBusinesses, 'ACTIVE'),
                      onSuspend: () => _bulk(selectedBusinesses, 'SUSPENDED'),
                      onClear: () => setState(_selected.clear),
                    ),
                  ],
                  const SizedBox(height: FactorySpacing.space4),
                  if (visible.isEmpty)
                    FactoryEmptyState(icon: Icons.search_off_rounded, title: l10n.noMatches, message: '')
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        void open(Business b) => showBusinessDetails(context, b.id);
                        void change(Business b, String next) => changeBusinessStatus(context, ref, b, next);
                        if (constraints.maxWidth >= businessesTableMinWidth) {
                          return BusinessesTable(
                            businesses: visible,
                            canModerate: canModerate,
                            onOpen: open,
                            onChangeStatus: change,
                            selected: selectedBusinesses.map((b) => b.id).toSet(),
                            onToggle: canModerate
                                ? (id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id))
                                : null,
                            sortColumn: _sortColumn,
                            sortAscending: _sortAscending,
                            onSort: (column) => setState(() {
                              // Same column flips direction; a new one starts ascending.
                              _sortAscending = _sortColumn == column ? !_sortAscending : true;
                              _sortColumn = column;
                            }),
                            onToggleAll: (all) => setState(() {
                              _selected.clear();
                              if (all) _selected.addAll(visible.map((b) => b.id));
                            }),
                          );
                        }
                        return Column(
                          children: [
                            for (final business in visible)
                              Padding(
                                padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                                child: _BusinessCard(
                                  business: business,
                                  canModerate: canModerate,
                                  onOpen: () => open(business),
                                  onChangeStatus: (next) => change(business, next),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Approve / suspend / reinstate. Suspending hides the business from
/// customers and stops its bookings, so it asks first and takes an optional
/// reason for the activity log; approving a still-invisible business doesn't.
Future<void> changeBusinessStatus(BuildContext context, WidgetRef ref, Business business, String next) async {
  final l10n = AppLocalizations.of(context)!;
  String? reason;
  if (next == 'SUSPENDED') {
    reason = await promptText(
      context,
      title: l10n.suspendTitle(business.name),
      message: l10n.suspendMessage,
      fieldLabel: l10n.reasonOptional,
      confirmLabel: l10n.suspend,
      destructive: true,
    );
    if (reason == null) return;
  }
  try {
    await ref
        .read(businessApiProvider)
        .setStatus(business.id, next, reason: (reason == null || reason.isEmpty) ? null : reason);
    ref.invalidate(businessesProvider);
    if (!context.mounted) return;
    showSnack(context, switch ((business.status, next)) {
      (_, 'SUSPENDED') => l10n.businessWasSuspended(business.name),
      ('SUSPENDED', _) => l10n.businessWasReinstated(business.name),
      _ => l10n.businessWasApproved(business.name),
    });
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(l10n, error));
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onShow});

  final int count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Material(
      color: colors.accentTint,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onShow,
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          child: Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: colors.text),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Text(
                  l10n.businessesPendingBanner(count),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.business,
    required this.canModerate,
    required this.onOpen,
    required this.onChangeStatus,
  });

  final Business business;
  final bool canModerate;
  final VoidCallback onOpen;
  final ValueChanged<String> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    final actions = <Widget>[
      if (canModerate && business.status == 'PENDING')
        FactoryButton(label: l10n.approve, onPressed: () => onChangeStatus('ACTIVE')),
      if (canModerate && business.status == 'SUSPENDED')
        FactoryButton(label: l10n.reinstate, onPressed: () => onChangeStatus('ACTIVE')),
      if (canModerate && business.status != 'SUSPENDED')
        FactoryButton(
          label: l10n.suspend,
          variant: FactoryButtonVariant.textDanger,
          onPressed: () => onChangeStatus('SUSPENDED'),
        ),
    ];

    return FactoryCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FactoryAvatar(
                initials: initialsFor(business.name),
                image: business.coverPhotoUrl != null ? NetworkImage(business.coverPhotoUrl!) : null,
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business.name, style: textTheme.titleSmall?.copyWith(color: colors.text)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        verticalLabel(l10n, business.vertical),
                        if (business.createdAt != null)
                          l10n.businessRegistered(formatDate(locale, business.createdAt!)),
                      ].join(' · '),
                      style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Flexible(
                child: ToneBadge(
                  label: businessStatusLabel(l10n, business.status),
                  tone: businessStatusTone(business.status),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showBusinessDetails(BuildContext context, String businessId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _BusinessDetails(businessId: businessId),
  );
}

class _BusinessDetails extends ConsumerWidget {
  const _BusinessDetails({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final canModerate = ref.watch(permissionsProvider).canModerateBusinesses;
    // Read from the live list so the sheet reflects an approve / suspend.
    final business = ref.watch(businessesProvider).value?.where((b) => b.id == businessId).firstOrNull;
    if (business == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    final overview = ref.watch(businessOverviewProvider(businessId)).value;
    final payouts =
        ref.watch(payoutsProvider(null)).value?.where((p) => p.providerId == businessId).toList() ?? const [];

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          ),
          Expanded(child: SelectableText(value, style: textTheme.bodyMedium)),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(FactorySpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (business.coverPhotoUrl != null) ...[
            ClipRRect(
              borderRadius: FactoryRadius.mdRadius,
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  business.coverPhotoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: FactorySpacing.space4),
          ],
          Row(
            children: [
              Expanded(child: Text(business.name, style: textTheme.headlineSmall)),
              ToneBadge(label: businessStatusLabel(l10n, business.status), tone: businessStatusTone(business.status)),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          row(l10n.detailVertical, verticalLabel(l10n, business.vertical)),
          if (business.createdAt != null) row(l10n.detailRegistered, formatDateTime(locale, business.createdAt!)),
          if (business.latitude != null && business.longitude != null)
            row(
              l10n.detailLocation,
              '${business.latitude!.toStringAsFixed(5)}, ${business.longitude!.toStringAsFixed(5)}',
            ),
          if (overview != null) ...[
            if (overview.ownerName != null) row(l10n.detailOwner, overview.ownerName!),
            if (overview.ownerEmail != null || overview.ownerPhone != null)
              row(l10n.detailContact, [overview.ownerEmail, overview.ownerPhone].whereType<String>().join(' · ')),
            row(l10n.detailServices, '${overview.servicesCount}'),
            row(l10n.detailBookings, l10n.detailBookingsValue(overview.totalBookings, overview.completedBookings)),
          ],
          // Codes for support tickets and logs, out of the way until asked for.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.detailTechnicalIds, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              children: [
                row(l10n.detailOwnerId, business.ownerUserId),
                row(l10n.detailBusinessId, business.id),
              ],
            ),
          ),
          const SizedBox(height: FactorySpacing.space4),
          FactorySectionHeader(title: l10n.detailPayouts),
          const SizedBox(height: FactorySpacing.space2),
          if (payouts.isEmpty)
            Text(l10n.detailNoPayouts, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))
          else
            for (final payout in payouts.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatMoney(locale, payout.amount, payout.currency)} · ${formatDate(locale, payout.createdAt)}',
                      ),
                    ),
                    ToneBadge(label: payoutStatusLabel(l10n, payout.status), tone: payoutStatusTone(payout.status)),
                  ],
                ),
              ),
          if (canModerate) ...[
            const SizedBox(height: FactorySpacing.space5),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: [
                if (business.status == 'PENDING')
                  FactoryButton(
                    label: l10n.approve,
                    onPressed: () async {
                      await changeBusinessStatus(context, ref, business, 'ACTIVE');
                    },
                  ),
                if (business.status == 'SUSPENDED')
                  FactoryButton(
                    label: l10n.reinstate,
                    onPressed: () => changeBusinessStatus(context, ref, business, 'ACTIVE'),
                  ),
                if (business.status != 'SUSPENDED')
                  FactoryButton(
                    label: l10n.suspend,
                    variant: FactoryButtonVariant.textDanger,
                    onPressed: () => changeBusinessStatus(context, ref, business, 'SUSPENDED'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


/// Appears while rows are checked: how many, and the actions that apply.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.busy,
    required this.canApprove,
    required this.canSuspend,
    required this.onApprove,
    required this.onSuspend,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final bool canApprove;
  final bool canSuspend;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: FactoryRadius.mdRadius,
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: FactorySpacing.space2,
        runSpacing: FactorySpacing.space2,
        children: [
          Text(l10n.bulkSelected(count), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text)),
          if (canApprove)
            FactoryButton(dense: true, label: l10n.approve, isLoading: busy, onPressed: onApprove),
          if (canSuspend)
            FactoryButton(
              dense: true,
              label: l10n.suspend,
              variant: FactoryButtonVariant.textDanger,
              onPressed: busy ? null : onSuspend,
            ),
          FactoryButton(dense: true, label: l10n.bulkClear, variant: FactoryButtonVariant.text, onPressed: busy ? null : onClear),
        ],
      ),
    );
  }
}

/// Saved views as chips (tap applies, the x removes) plus "Save view" for the
/// current filter and search when it isn't saved yet.
class _SavedViewsRow extends ConsumerWidget {
  const _SavedViewsRow({required this.status, required this.query, required this.onApply});

  final String? status;
  final String query;
  final ValueChanged<SavedView> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(savedViewsProvider).value ?? const <SavedView>[];
    final hasFilter = status != null || query.trim().isNotEmpty;
    final alreadySaved = views.any((v) => v.matches(status, query));
    if (views.isEmpty && !hasFilter) return const SizedBox.shrink();

    Future<void> save() async {
      final name = await promptText(
        context,
        title: l10n.businessesSaveViewTitle,
        fieldLabel: l10n.businessesViewName,
        confirmLabel: l10n.businessesSaveView,
        required: true,
      );
      if (name == null || name.trim().isEmpty || !context.mounted) return;
      final ok = await ref
          .read(savedViewsProvider.notifier)
          .add(SavedView(name: name.trim(), status: status, query: query.trim()));
      if (!ok && context.mounted) showSnack(context, l10n.businessesViewsLimit);
    }

    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space2),
      child: Wrap(
        spacing: FactorySpacing.space2,
        runSpacing: FactorySpacing.space1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final view in views)
            InputChip(
              label: Text(view.name),
              selected: view.matches(status, query),
              onPressed: () => onApply(view),
              deleteButtonTooltipMessage: l10n.businessesRemoveView,
              onDeleted: () => ref.read(savedViewsProvider.notifier).remove(view.name),
            ),
          if (hasFilter && !alreadySaved)
            FactoryButton(
              dense: true,
              icon: Icons.bookmark_add_outlined,
              label: l10n.businessesSaveView,
              variant: FactoryButtonVariant.text,
              onPressed: save,
            ),
        ],
      ),
    );
  }
}


/// Underlined status tabs with counts: All, awaiting approval, active,
/// suspended. A null value is "All". Scrolls sideways when the labels are
/// longer than the width (Russian and Kazakh run longer).
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.counts, required this.onSelect});

  final String? selected;
  final Map<String?, int> counts;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    Widget tab(String? status, String label) {
      final isSelected = selected == status;
      final tone = isSelected ? colors.primary : colors.textSecondary;
      return Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: () => onSelect(status),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isSelected ? colors.primary : Colors.transparent, width: 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(color: tone, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                ),
                const SizedBox(width: FactorySpacing.space2),
                Text('${counts[status] ?? 0}', style: FactoryTypography.mono(size: 12, weight: FontWeight.w500, color: tone)),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            tab(null, l10n.filterAll),
            for (final status in const ['PENDING', 'ACTIVE', 'SUSPENDED']) tab(status, businessStatusLabel(l10n, status)),
          ],
        ),
      ),
    );
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/business_analytics.dart';
import '../providers/salon_providers.dart';

/// The Action Center's "rebook opportunity"/"retention risk" drill-down --
/// the individual customers behind one of the customer-analytics counts,
/// read-only (no rebooking-workflow UI exists yet in this app).
class CustomerListScreen extends ConsumerStatefulWidget {
  final String providerId;
  final CustomerRetentionStatus? retentionStatus;
  final String title;

  const CustomerListScreen({super.key, required this.providerId, this.retentionStatus, required this.title});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(CustomerListItem customer) {
    final needle = _filter.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return (customer.displayName ?? '').toLowerCase().contains(needle) ||
        (customer.email ?? '').toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final providerId = widget.providerId;
    final retentionStatus = widget.retentionStatus;
    final customersAsync = ref.watch(customerListProvider((providerId, retentionStatus)));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: widget.title),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space6),
                child: FactoryEmptyState(icon: Icons.groups_outlined, title: l10n.customerListEmpty, message: ''),
              ),
            );
          }
          final locale = Localizations.localeOf(context).toString();
          final shown = customers.where(_matches).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  0,
                ),
                child: FactorySearchField(
                  controller: _searchController,
                  hint: l10n.customerListSearchHint,
                  onChanged: (value) => setState(() => _filter = value),
                  onCleared: () => setState(() => _filter = ''),
                  clearSemanticLabel: l10n.customerListSearchClear,
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(FactorySpacing.space6),
                          child: FactoryEmptyState(
                            icon: Icons.search_off_rounded,
                            title: l10n.customerListNoMatch,
                            message: '',
                            compact: true,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(FactorySpacing.space4),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
                        itemBuilder: (context, index) => _CustomerCard(customer: shown[index], locale: locale),
                      ),
              ),
            ],
          );
        },
        loading: () => const FactoryLoadingState(),
        error: (error, _) => FactoryErrorState(
          message: l10n.errorAnalyticsLoadFailed(error.toString()),
          onRetry: () => ref.invalidate(customerListProvider((providerId, retentionStatus))),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerListItem customer;
  final String locale;

  const _CustomerCard({required this.customer, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    final name = customer.displayName ?? customer.email ?? '—';

    return FactoryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactoryAvatar(initials: _initialsFor(name), size: FactoryAvatarSize.md),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(child: _details(context, l10n, colors)),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, AppLocalizations l10n, FactoryColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                customer.displayName ?? customer.email ?? '—',
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FactorySpacing.space3),
            FactoryPriceText(amount: customer.totalSpent, fontSize: 14),
          ],
        ),
        if (customer.favouriteServiceTitle != null) ...[
          const SizedBox(height: 4),
          Text(
            customer.favouriteServiceTitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
        const SizedBox(height: FactorySpacing.space2),
        Wrap(
          spacing: FactorySpacing.space3,
          runSpacing: 4,
          children: [
            if (customer.lastVisitAt != null)
              Text(
                l10n.customerListLastVisitLabel(DateFormat.yMMMd(locale).format(customer.lastVisitAt!.toLocal())),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (customer.nextExpectedVisitAt != null)
              Text(
                l10n.customerListNextExpectedLabel(
                  DateFormat.yMMMd(locale).format(customer.nextExpectedVisitAt!.toLocal()),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
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

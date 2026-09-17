import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_customer.dart';
import '../providers/loyalty_admin_providers.dart';
import '../widgets/loyalty_retention_badge.dart';
import 'loyalty_customer_detail_screen.dart';

/// The loyalty roster -- paginated exactly like [CampaignCenterScreen]'s
/// campaign list (accumulate pages locally, "load more" when there's
/// another). The backend list endpoint takes no search parameter, so the
/// search field here filters the pages already loaded rather than
/// re-querying the server -- an owner narrowing down a list they can
/// already see, not a full-roster server-side search.
class LoyaltyCustomersScreen extends ConsumerStatefulWidget {
  final String providerId;

  const LoyaltyCustomersScreen({super.key, required this.providerId});

  @override
  ConsumerState<LoyaltyCustomersScreen> createState() => _LoyaltyCustomersScreenState();
}

class _LoyaltyCustomersScreenState extends ConsumerState<LoyaltyCustomersScreen> {
  int _page = 0;
  final List<LoyaltyCustomerInsight> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;
  final _searchController = TextEditingController();
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (widget.providerId, _page);
    final pageAsync = ref.watch(loyaltyCustomersProvider(key));

    ref.listen(loyaltyCustomersProvider(key), (previous, next) {
      next.whenData((resp) {
        if (_loadedPages.add(resp.number)) {
          setState(() {
            _items.addAll(resp.content);
            _totalPages = resp.totalPages;
          });
        }
      });
    });

    final filtered = _search.isEmpty
        ? _items
        : _items.where((c) {
            final q = _search.toLowerCase();
            return (c.displayName?.toLowerCase().contains(q) ?? false) ||
                (c.email?.toLowerCase().contains(q) ?? false);
          }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(loyaltyCustomersProvider);
        setState(_resetPaging);
      },
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          FactorySearchField(
            controller: _searchController,
            hint: l10n.loyaltyCustomersSearchHint,
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: FactorySpacing.space4),
          if (_items.isEmpty)
            pageAsync.when(
              data: (resp) => resp.content.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                      child: Center(
                        child: Text(
                          l10n.loyaltyCustomersEmpty,
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
                  message: l10n.errorLoyaltyCustomersLoadFailed(error.toString()),
                  onRetry: () => ref.invalidate(loyaltyCustomersProvider(key)),
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
              child: Center(
                child: Text(
                  l10n.loyaltyCustomersSearchEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                ),
              ),
            )
          else ...[
            for (final customer in filtered) ...[
              _CustomerRow(
                customer: customer,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoyaltyCustomerDetailScreen(providerId: widget.providerId, userId: customer.userId),
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
            ],
            if (_search.isEmpty && _page + 1 < _totalPages)
              Center(
                child: pageAsync.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(FactorySpacing.space4),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : FactoryButton(
                        label: l10n.loyaltyCustomersLoadMore,
                        variant: FactoryButtonVariant.secondary,
                        onPressed: () => setState(() => _page += 1),
                      ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final LoyaltyCustomerInsight customer;
  final VoidCallback onTap;

  const _CustomerRow({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return FactoryCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.displayName ?? customer.email ?? '—',
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space2),
                    LoyaltyRetentionBadge(status: customer.retentionStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.loyaltyCustomerBalanceLabel(customer.pointsBalance),
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (customer.lastActivityAt != null)
                  Text(
                    l10n.loyaltyCustomerLastActivityLabel(DateFormat.yMMMd(locale).format(customer.lastActivityAt!.toLocal())),
                    style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
      ),
    );
  }
}

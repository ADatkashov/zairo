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
class CustomerListScreen extends ConsumerWidget {
  final String providerId;
  final CustomerRetentionStatus? retentionStatus;
  final String title;

  const CustomerListScreen({super.key, required this.providerId, this.retentionStatus, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final customersAsync = ref.watch(customerListProvider((providerId, retentionStatus)));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: title),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.space6),
                child: Text(
                  l10n.customerListEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                ),
              ),
            );
          }
          final locale = Localizations.localeOf(context).toString();
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _CustomerCard(customer: customers[index], locale: locale),
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

    return FactoryCard(
      child: Column(
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
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import 'commission_tab.dart';
import 'payouts_tab.dart';
import 'refunds_tab.dart';
import 'subscription_tab.dart';

/// Money in motion: what businesses are owed (payouts) and money that has to
/// go back to customers (refunds), plus the marketplace commission rates.
/// `/finance?tab=refunds` opens the second tab, `?tab=commission` the third, `?tab=subscription` the fourth.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      // A new key per deep link so the tab follows the URL.
      key: ValueKey(initialTab),
      length: 4,
      initialIndex: switch (initialTab) {
        'refunds' => 1,
        'commission' => 2,
        'subscription' => 3,
        _ => 0,
      },
      child: AreaScaffold(
        title: l10n.navFinance,
        bottom: TabBar(
          // Four tabs do not fit a phone side by side without cutting their names; they scroll instead.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.financePayouts),
            Tab(text: l10n.financeRefunds),
            Tab(text: l10n.financeCommission),
            Tab(text: l10n.financeSubscription),
          ],
        ),
        body: const ContentFrame(child: TabBarView(children: [PayoutsTab(), RefundsTab(), CommissionTab(), SubscriptionTab()])),
      ),
    );
  }
}

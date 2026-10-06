import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import 'payouts_tab.dart';
import 'refunds_tab.dart';

/// Money in motion: what businesses are owed (payouts) and money that has to
/// go back to customers (refunds). `/finance?tab=refunds` opens the second tab.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      // A new key per deep link so the tab follows the URL.
      key: ValueKey(initialTab),
      length: 2,
      initialIndex: initialTab == 'refunds' ? 1 : 0,
      child: AreaScaffold(
        title: l10n.navFinance,
        bottom: TabBar(
          tabs: [
            Tab(text: l10n.financePayouts),
            Tab(text: l10n.financeRefunds),
          ],
        ),
        body: const ContentFrame(child: TabBarView(children: [PayoutsTab(), RefundsTab()])),
      ),
    );
  }
}

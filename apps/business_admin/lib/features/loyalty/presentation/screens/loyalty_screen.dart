import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/no_business_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import 'loyalty_birthdays_screen.dart';
import 'loyalty_customers_screen.dart';
import 'loyalty_milestones_screen.dart';
import 'loyalty_overview_screen.dart';
import 'loyalty_redemptions_screen.dart';
import 'loyalty_rewards_screen.dart';
import 'loyalty_settings_screen.dart';
import 'loyalty_tiers_screen.dart';

/// The Loyalty & Rewards top-level destination -- resolves which business
/// is being managed exactly like [CampaignCenterScreen] (that's this app's
/// established shared-provider mechanism: `myProvidersProvider(ownerUserId)`
/// plus a chip picker for an owner with more than one business, skipping
/// straight to its data for an owner with exactly one), then hosts every
/// Loyalty admin surface as tabs under one AppBar so an owner setting up
/// the program for the first time can move Settings -> Rewards -> Overview
/// without leaving the feature.
class LoyaltyScreen extends ConsumerStatefulWidget {
  final String ownerUserId;

  const LoyaltyScreen({super.key, required this.ownerUserId});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
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
      appBar: FactoryAppBar(title: l10n.loyaltyScreenTitle),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return NoBusinessState(message: l10n.loyaltyNoBusinesses);
          }
          if (_providerId == null || !providers.any((p) => p.id == _providerId)) {
            _providerId = providers.first.id;
          }
          return _LoyaltyBody(providerId: _providerId!, providers: providers, onSelectProvider: _selectProvider);
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

class _LoyaltyBody extends StatelessWidget {
  final String providerId;
  final List<AdminProvider> providers;
  final ValueChanged<String> onSelectProvider;

  const _LoyaltyBody({required this.providerId, required this.providers, required this.onSelectProvider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    // Four tabs instead of eight: related parts share a tab behind a small
    // switcher (what a small business owner scans for is "rewards", "customers"
    // and "the programme's rules", not eight separate pages).
    // Four labels share the width; a long one (Customers) shrinks a little instead of being cut off.
    Tab tab(String label) => Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)));
    final tabs = [
      tab(l10n.loyaltyTabOverview),
      tab(l10n.loyaltyTabRewards),
      tab(l10n.loyaltyTabCustomers),
      tab(l10n.loyaltyTabProgram),
    ];
    final tabViews = [
      LoyaltyOverviewScreen(providerId: providerId),
      _PaneSwitcher(
        key: ValueKey('rewards-$providerId'),
        labels: [l10n.loyaltyTabRewards, l10n.loyaltyTabRedemptions],
        builders: [
          () => LoyaltyRewardsScreen(providerId: providerId),
          () => LoyaltyRedemptionsScreen(providerId: providerId),
        ],
      ),
      _PaneSwitcher(
        key: ValueKey('customers-$providerId'),
        labels: [l10n.loyaltyTabCustomers, l10n.loyaltyTabBirthdays],
        builders: [
          () => LoyaltyCustomersScreen(providerId: providerId),
          () => LoyaltyBirthdaysScreen(providerId: providerId),
        ],
      ),
      _PaneSwitcher(
        key: ValueKey('program-$providerId'),
        labels: [l10n.loyaltyTabSettings, l10n.loyaltyTabMilestones, l10n.loyaltyTabTiers],
        builders: [
          () => LoyaltySettingsScreen(providerId: providerId),
          () => LoyaltyMilestonesScreen(providerId: providerId),
          () => LoyaltyTiersScreen(providerId: providerId),
        ],
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
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
          Container(
            color: colors.surface,
            child: TabBar(tabs: tabs, labelPadding: const EdgeInsets.symmetric(horizontal: 4)),
          ),
          Expanded(child: TabBarView(children: tabViews)),
        ],
      ),
    );
  }
}

/// Parts of one tab, one visible at a time. A part is built the first time it
/// is shown and then kept, so a half-filled form survives a look at its sibling.
class _PaneSwitcher extends StatefulWidget {
  final List<String> labels;
  final List<Widget Function()> builders;

  const _PaneSwitcher({super.key, required this.labels, required this.builders});

  @override
  State<_PaneSwitcher> createState() => _PaneSwitcherState();
}

class _PaneSwitcherState extends State<_PaneSwitcher> with AutomaticKeepAliveClientMixin {
  int _selected = 0;
  final Set<int> _built = {0};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space3, FactorySpacing.space4, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [for (var i = 0; i < widget.labels.length; i++) ButtonSegment(value: i, label: Text(widget.labels[i]))],
              selected: {_selected},
              onSelectionChanged: (value) => setState(() {
                _selected = value.first;
                _built.add(_selected);
              }),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selected,
            children: [
              for (var i = 0; i < widget.builders.length; i++) _built.contains(i) ? widget.builders[i]() : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

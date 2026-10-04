import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/automation/presentation/screens/automation_center_screen.dart';
import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../l10n/app_localizations.dart';

/// The "More" tab of the phone/tablet shell: the destinations that don't earn
/// a slot in a five-item bottom bar (Automation, Subscription, Settings). The
/// desktop sidebar lists all of them directly.
class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final ownerUserId = ref.watch(authControllerProvider).value?.id;

    Widget tile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
      child: FactorySelectableTile(
        title: label,
        leading: Icon(icon, color: colors.textSecondary),
        trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
        onTap: onTap,
      ),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.navMore, automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          if (ownerUserId != null)
            tile(
              icon: Icons.bolt_outlined,
              label: l10n.automationCenterNavLabel,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AutomationCenterScreen(ownerUserId: ownerUserId)),
              ),
            ),
          tile(
            icon: Icons.receipt_long_outlined,
            label: l10n.billingScreenTitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BillingScreen()),
            ),
          ),
          tile(
            icon: Icons.settings_outlined,
            label: l10n.settingsButtonTooltip,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

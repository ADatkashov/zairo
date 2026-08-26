import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../screens/login_screen.dart';

/// Shown in place of a tab's content when it's reached directly (bottom nav)
/// while logged out — Bookings and Favorites are now peer tabs to Home/
/// Search/Profile, not screens only reachable after already being logged
/// in, so each needs its own inline prompt instead of assuming a caller
/// already gated access (the pattern FavoriteButton/ProviderDetailScreen's
/// Book button use for an in-flow action, not a whole tab).
class LoggedOutGate extends StatelessWidget {
  final IconData icon;
  final String message;

  const LoggedOutGate({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: colors.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: FactoryIconSize.lg, color: colors.textTertiary),
            ),
            const SizedBox(height: FactorySpacing.space4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: FactorySpacing.space5),
            FactoryButton(
              label: l10n.loginTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

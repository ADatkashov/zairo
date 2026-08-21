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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: Text(l10n.loginTitle),
            ),
          ],
        ),
      ),
    );
  }
}

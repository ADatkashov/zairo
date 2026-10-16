import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_navigation.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../providers/waitlist_providers.dart';

/// The "no open times" state of a business, with the one thing a customer can do about it: ask to be told the moment
/// a time frees up. One tap, no form (any time will do). Logged out, the button opens LoginScreen — same gate as
/// the favorite button. Once on the list the state says so and offers to leave it.
class NoTimesWaitlist extends ConsumerStatefulWidget {
  final String providerId;

  const NoTimesWaitlist({super.key, required this.providerId});

  @override
  ConsumerState<NoTimesWaitlist> createState() => _NoTimesWaitlistState();
}

class _NoTimesWaitlistState extends ConsumerState<NoTimesWaitlist> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(authControllerProvider).value;

    // A failed or slow lookup just shows the join button: joining is idempotent on the backend.
    final waiting = currentUser == null
        ? false
        : (ref.watch(waitingProviderIdsProvider(currentUser.id)).value ?? const <String>{}).contains(widget.providerId);

    if (waiting) {
      return FactoryEmptyState(
        compact: true,
        icon: Symbols.notifications_active_rounded,
        title: l10n.waitlistJoinedTitle,
        message: l10n.waitlistJoinedMessage,
        actionLabel: l10n.waitlistLeaveButton,
        onAction: _busy ? null : () => _change(currentUser!.id, join: false),
      );
    }
    return FactoryEmptyState(
      compact: true,
      icon: Symbols.event_busy_rounded,
      title: l10n.noOpenTimesTitle,
      message: l10n.noOpenTimesWaitlistMessage,
      actionLabel: l10n.waitlistJoinButton,
      onAction: _busy
          ? null
          : () {
              if (currentUser == null) {
                pushAuthScreen(context, const LoginScreen());
                return;
              }
              _change(currentUser.id, join: true);
            },
    );
  }

  Future<void> _change(String userId, {required bool join}) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(waitlistApiProvider);
    try {
      if (join) {
        await api.join(userId, widget.providerId);
      } else {
        await api.leave(userId, widget.providerId);
      }
      ref.invalidate(waitingProviderIdsProvider(userId));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.waitlistFailed)));
    }
    if (mounted) setState(() => _busy = false);
  }
}

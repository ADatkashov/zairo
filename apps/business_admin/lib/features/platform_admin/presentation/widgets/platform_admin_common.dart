import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../platform_admin_labels.dart';

/// Keeps console content readable on a wide web window instead of stretching
/// rows across the whole screen.
class PlatformContentFrame extends StatelessWidget {
  const PlatformContentFrame({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 880;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A coloured pill with the translated status.
class PlatformStatusBadge extends StatelessWidget {
  const PlatformStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      'ACTIVE' => FactoryBadgeVariant.available,
      'PENDING' => FactoryBadgeVariant.limited,
      'SUSPENDED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };
    return FactoryBadge(label: platformStatusLabel(AppLocalizations.of(context)!, status), variant: variant);
  }
}

/// Full-tab friendly error with a retry button.
class PlatformLoadError extends StatelessWidget {
  const PlatformLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: FactoryErrorState(message: l10n.paLoadFailed, onRetry: onRetry, retryLabel: l10n.paRetry),
    );
  }
}

/// Centered empty state that still supports pull-to-refresh.
class PlatformEmptyState extends StatelessWidget {
  const PlatformEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRefresh,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRefresh;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final empty = Center(
      child: FactoryEmptyState(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
    if (onRefresh == null) return empty;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: empty)],
        ),
      ),
    );
  }
}

void showPlatformSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A confirm / cancel dialog; resolves to true only when confirmed.
Future<bool> confirmPlatformAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showFactoryDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: confirmLabel,
          variant: destructive ? FactoryButtonVariant.danger : FactoryButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    ],
  );
  return confirmed == true;
}

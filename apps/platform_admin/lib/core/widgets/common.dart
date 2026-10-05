import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../network/error_text.dart';

/// Keeps content readable on a wide desktop window instead of stretching
/// rows across the whole screen.
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// One area of the console: an app bar, the body, and an optional add button.
/// Every area uses this so titles, actions and the add button sit in the same
/// place whatever the screen size.
class AreaScaffold extends StatelessWidget {
  const AreaScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.bottom,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions, bottom: bottom, automaticallyImplyLeading: false),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// `loading → spinner`, `error → message + retry`, `data → builder`. A
/// refresh keeps showing the old data instead of flashing a spinner.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.onRetry, required this.builder});

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LoadError(error: error, onRetry: onRetry),
      data: builder,
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        child: FactoryErrorState(
          message: '${l10n.loadFailed}\n${describeError(l10n, error)}',
          onRetry: onRetry,
          retryLabel: l10n.retry,
        ),
      ),
    );
  }
}

/// Centered empty state that still supports pull-to-refresh.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
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

/// A coloured pill: green / amber / red / grey.
enum Tone { good, warn, bad, neutral }

class ToneBadge extends StatelessWidget {
  const ToneBadge({super.key, required this.label, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FactoryBadge(
      label: label,
      icon: icon,
      variant: switch (tone) {
        Tone.good => FactoryBadgeVariant.available,
        Tone.warn => FactoryBadgeVariant.limited,
        Tone.bad => FactoryBadgeVariant.error,
        Tone.neutral => FactoryBadgeVariant.neutral,
      },
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirm / cancel; resolves to true only when confirmed. [destructive]
/// paints the confirm button red.
Future<bool> confirmAction(
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
          label: l10n.cancel,
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

/// Confirm dialog with a free-text field. Resolves to null when cancelled,
/// otherwise the typed text (possibly empty when [required] is false).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  required String fieldLabel,
  required String confirmLabel,
  bool required = false,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
      required: required,
      destructive: destructive,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.required,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String fieldLabel;
  final String confirmLabel;
  final bool required;
  final bool destructive;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.fieldRequired);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: widget.title,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: FactorySpacing.space3)],
            FactoryTextField(
              controller: _controller,
              label: widget.fieldLabel,
              errorText: _error,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: widget.confirmLabel,
          variant: widget.destructive ? FactoryButtonVariant.danger : FactoryButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Lays children out in as many equal columns as fit [minTileWidth] — one on
/// a phone, two or three on a tablet, up to [maxColumns] on a desktop.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 260,
    this.maxColumns = 4,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(1, maxColumns);
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// "SOME_CODE" -> "Some code" — the fallback for a code the app has no
/// translation for yet.
String humanizeCode(String code) {
  final words = code.replaceAll('_', ' ').trim().toLowerCase();
  return words.isEmpty ? code : '${words[0].toUpperCase()}${words.substring(1)}';
}

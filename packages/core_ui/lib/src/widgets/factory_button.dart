import 'package:flutter/material.dart';

/// Which of the Component Library's button roles this is — drives color
/// only; height/radius/padding all come from the theme's
/// `FilledButton`/`OutlinedButton`/`TextButton` styles (`factory_theme.dart`)
/// so every Factory button shares one shape regardless of variant. [danger]
/// is the filled, high-emphasis destructive action (a confirm-delete
/// dialog's final button); [textDanger] is the low-emphasis inline one (a
/// "Cancel booking" link sitting on a card among several) — same red,
/// different weight, same distinction [primary]/[text] already draw.
enum FactoryButtonVariant { primary, secondary, text, danger, textDanger }

/// The screen's primary or secondary action — "Book", "Cancel", "Delete
/// account". Wraps Flutter's own button widgets rather than reinventing
/// press/hover/focus/disabled handling; this only adds the parts the design
/// system needs on top: a fixed variant set, a loading spinner that replaces
/// the label instead of sitting beside it, and an [expand] full-width mode
/// for a sticky bottom CTA.
class FactoryButton extends StatelessWidget {
  const FactoryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FactoryButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;

  /// Null (not a separate `enabled` flag) disables the button — the same
  /// contract every Material button already uses.
  final VoidCallback? onPressed;
  final FactoryButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Fills the width of its parent — the common case for a bottom-anchored
  /// booking CTA. False renders at intrinsic (label) width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final pressHandler = isLoading ? null : onPressed;

    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _spinnerColor(context)),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    final button = switch (variant) {
      FactoryButtonVariant.primary => FilledButton(onPressed: pressHandler, child: child),
      FactoryButtonVariant.secondary => OutlinedButton(onPressed: pressHandler, child: child),
      FactoryButtonVariant.text => TextButton(onPressed: pressHandler, child: child),
      FactoryButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
          ),
          onPressed: pressHandler,
          child: child,
        ),
      FactoryButtonVariant.textDanger => TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: pressHandler,
          child: child,
        ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _spinnerColor(BuildContext context) => switch (variant) {
        FactoryButtonVariant.primary || FactoryButtonVariant.danger => Theme.of(context).colorScheme.onPrimary,
        FactoryButtonVariant.secondary || FactoryButtonVariant.text => Theme.of(context).colorScheme.primary,
        FactoryButtonVariant.textDanger => Theme.of(context).colorScheme.error,
      };
}

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_control_size.dart';
import '../theme/factory_radius.dart';

/// Which of the Component Library's button roles this is — drives color
/// only; height/radius/padding all come from the theme's
/// `FilledButton`/`OutlinedButton`/`TextButton` styles (`factory_theme.dart`)
/// so every Factory button shares one shape regardless of variant. [danger]
/// is the filled, high-emphasis destructive action (a confirm-delete
/// dialog's final button); [textDanger] is the low-emphasis inline one (a
/// "Cancel booking" link sitting on a card among several) — same red,
/// different weight, same distinction [primary]/[text] already draw.
///
/// [tonal] is the soft-filled secondary action (ZAIRO 2.0, Figma "Secondary"):
/// `primaryTint` fill with `primaryStrong` label — less shouty than [primary],
/// more present than the outlined [secondary] (Figma "Outline").
///
/// [gradient] is the one deliberate exception to "every Factory button
/// shares one shape": the Customer App Redesign board's sticky booking CTA
/// (`primaryStrong` → `mint`, pill radius, a soft colored shadow) — reach
/// for it only on the one or two screens with a money-moving bottom action
/// (booking confirm, provider profile's "Book"), not as a general
/// alternative to [primary].
enum FactoryButtonVariant { primary, secondary, tonal, text, danger, textDanger, gradient }

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
    this.dense = false,
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

  /// A 36px-high button for pointer-driven, data-dense surfaces (table rows,
  /// toolbars on desktop). Below the 44px touch target, so don't use it on
  /// phone layouts.
  final bool dense;

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
              // Flexible (loose): a long label wraps inside a width-constrained
              // button instead of overflowing; at intrinsic width nothing changes.
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    final ButtonStyle? denseStyle = dense
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, FactoryButtonHeight.sm)),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;

    final button = switch (variant) {
      FactoryButtonVariant.primary => FilledButton(style: denseStyle, onPressed: pressHandler, child: child),
      FactoryButtonVariant.secondary => OutlinedButton(style: denseStyle, onPressed: pressHandler, child: child),
      FactoryButtonVariant.tonal => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.factoryColors.primaryTint,
            foregroundColor: context.factoryColors.primaryStrong,
            disabledBackgroundColor: context.factoryColors.primaryTint.withValues(alpha: 0.5),
            disabledForegroundColor: context.factoryColors.primaryStrong.withValues(alpha: 0.5),
          ).merge(denseStyle),
          onPressed: pressHandler,
          child: child,
        ),
      FactoryButtonVariant.text => TextButton(style: denseStyle, onPressed: pressHandler, child: child),
      FactoryButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            disabledBackgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
          ).merge(denseStyle),
          onPressed: pressHandler,
          child: child,
        ),
      FactoryButtonVariant.textDanger => TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error).merge(denseStyle),
          onPressed: pressHandler,
          child: child,
        ),
      FactoryButtonVariant.gradient => _GradientButton(onPressed: pressHandler, child: child),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _spinnerColor(BuildContext context) => switch (variant) {
        FactoryButtonVariant.primary ||
        FactoryButtonVariant.danger ||
        FactoryButtonVariant.gradient =>
          Theme.of(context).colorScheme.onPrimary,
        FactoryButtonVariant.secondary ||
        FactoryButtonVariant.tonal ||
        FactoryButtonVariant.text =>
          Theme.of(context).colorScheme.primary,
        FactoryButtonVariant.textDanger => Theme.of(context).colorScheme.error,
      };
}

/// The Customer App Redesign board's one gradient CTA — `primaryStrong` →
/// `mint` diagonal, pill radius, a soft colored shadow. Built as a plain
/// `Material`/`InkWell` rather than a themed `FilledButton` because
/// `ButtonStyle` has no gradient-background slot.
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final disabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      shape: FactoryRadius.pill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedOpacity(
          opacity: disabled ? 0.5 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: FactoryButtonHeight.md,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryStrong, colors.mint],
              ),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: colors.primaryStrong.withValues(alpha: 0.3),
                        offset: const Offset(0, 10),
                        blurRadius: 24,
                      ),
                    ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w700),
              child: IconTheme.merge(data: IconThemeData(color: colors.onPrimary), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

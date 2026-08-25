import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// [filled] reads as an active/primary action (rare — most icon buttons are
/// secondary chrome); [outline] is the default bordered-surface look most
/// screens want (favorite, share, notification-bell).
enum FactoryIconButtonVariant { filled, outline }

/// A single icon-only action. [semanticLabel] is required, not optional —
/// the design system's rule (and this package's own accessibility pass) is
/// that an icon button is never shipped without one; it doubles as the
/// visual long-press tooltip via [IconButton.tooltip].
class FactoryIconButton extends StatelessWidget {
  const FactoryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.variant = FactoryIconButtonVariant.outline,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final FactoryIconButtonVariant variant;

  /// The toggled/"on" state (e.g. a filter chip's icon-button twin). Always
  /// wins over [variant] visually — an active outline button still reads as
  /// active, not merely bordered.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final (Color bg, Color fg, BorderSide? side) = switch ((variant, isActive)) {
      (_, true) => (colors.primaryTint, colors.primaryStrong, null),
      (FactoryIconButtonVariant.filled, false) => (colors.primary, colors.onPrimary, null),
      (FactoryIconButtonVariant.outline, false) => (colors.surface, colors.text, BorderSide(color: colors.border)),
    };

    return IconButton(
      icon: Icon(icon),
      tooltip: semanticLabel,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        side: side,
        minimumSize: const Size(44, 44),
      ),
    );
  }
}

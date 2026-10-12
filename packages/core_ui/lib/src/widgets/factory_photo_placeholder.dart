import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// What a photo slot shows when there is no photo (or it failed to load): a
/// soft fill with the category's own icon, instead of an empty grey block.
///
/// With a [tint]/[color] pair (a category accent) the fill takes the category's
/// colour; without one it falls back to the neutral brand tint. The icon is
/// decoration only, so it is hidden from semantics.
class FactoryPhotoPlaceholder extends StatelessWidget {
  const FactoryPhotoPlaceholder({super.key, this.icon, this.color, this.tint});

  final IconData? icon;
  final Color? color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final tintBase = tint ?? colors.primaryTint;
    final ink = color ?? colors.primary;
    // A touch of the accent over the tint, so the category badge that sits on
    // top of this (it uses the plain tint) still reads as its own pill.
    final base = Color.alphaBlend(ink.withValues(alpha: 0.14), tintBase);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.alphaBlend(base.withValues(alpha: 0.4), colors.surfaceAlt),
          ],
        ),
      ),
      child: icon == null
          ? null
          // Scales with the slot (an 84px side photo vs a 128px top photo) and
          // never grows past 56. Deliberately not a LayoutBuilder: a card in a
          // list is measured with intrinsic sizes, which LayoutBuilder rejects.
          : ExcludeSemantics(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.42,
                  heightFactor: 0.42,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Icon(
                      icon,
                      size: 56,
                      color: ink.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

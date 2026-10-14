import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_spacing.dart';

/// A compact promotional tile: a `primaryStrong` → `primary` gradient inside
/// a `primary` outline, a bold [title] and an optional [subtitle]. Sits in a
/// short horizontal row (Home's "what's new" strip, the Astana Hub pattern);
/// each card is a tap target and may be dismissable.
class FactoryPromoCard extends StatelessWidget {
  const FactoryPromoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.onDismiss,
    this.dismissTooltip,
    this.width,
    this.height = 128,
  });

  final String title;
  final String? subtitle;

  /// A large, faded decorative glyph in the bottom-right corner.
  final IconData? icon;
  final VoidCallback? onTap;

  /// Shows a close button in the top-right corner when set.
  final VoidCallback? onDismiss;
  final String? dismissTooltip;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final onGradient = colors.onPrimary;
    return SizedBox(
      width: width,
      height: height,
      child: Semantics(
        button: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryStrong, colors.primary],
              ),
              borderRadius: FactoryRadius.xlRadius,
              border: Border.all(color: colors.primary, width: 2),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: FactoryRadius.xlRadius,
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  if (icon != null)
                    Positioned(
                      right: FactorySpacing.space3,
                      bottom: FactorySpacing.space2,
                      child: ExcludeSemantics(
                        child: Icon(icon, size: 48, fill: 1, color: onGradient.withValues(alpha: 0.22)),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      FactorySpacing.space4,
                      FactorySpacing.space4,
                      onDismiss != null ? FactorySpacing.space10 : FactorySpacing.space4,
                      FactorySpacing.space3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(color: onGradient),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: FactorySpacing.space1),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: onGradient.withValues(alpha: 0.85)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    Positioned(
                      top: FactorySpacing.space1,
                      right: FactorySpacing.space1,
                      child: IconButton(
                        onPressed: onDismiss,
                        tooltip: dismissTooltip,
                        icon: Icon(Icons.close_rounded, size: 18, color: onGradient),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// Circular initials avatar — the fallback every vertical uses before a
/// real photo loads (or when there isn't one). Callers who have an image
/// pass it as [image]; [initials] still backs it as the `child` shown
/// while the image loads or on error.
class FactoryAvatar extends StatelessWidget {
  const FactoryAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.background,
    this.foreground,
    this.image,
  });

  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background ?? colors.primaryTint,
      foregroundColor: foreground ?? colors.primaryStrong,
      backgroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: foreground ?? colors.primaryStrong,
              ),
            )
          : null,
    );
  }
}

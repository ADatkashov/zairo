import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';

/// A loading placeholder block. Shimmers by default; when the platform
/// requests reduced motion ([MediaQuery.disableAnimationsOf]) it renders as
/// a static tinted block instead — motion here is a nicety, not something
/// state depends on.
class FactorySkeleton extends StatefulWidget {
  const FactorySkeleton({super.key, required this.width, required this.height, this.borderRadius});

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<FactorySkeleton> createState() => _FactorySkeletonState();
}

class _FactorySkeletonState extends State<FactorySkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final radius = widget.borderRadius ?? FactoryRadius.smRadius;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 4 * t, 0),
              end: Alignment(1 + 4 * t, 0),
              colors: [colors.surfaceAlt, colors.border, colors.surfaceAlt],
            ),
          ),
        );
      },
    );
  }
}

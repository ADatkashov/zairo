import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';

/// The chrome every Factory bottom sheet shares: a drag handle and safe-area
/// padding, wrapping whatever content the call site builds. Color, top
/// radius and elevation already come from `factory_theme.dart`'s
/// `bottomSheetTheme` — this only adds the parts a stock `showModalBottomSheet`
/// leaves to the caller.
class FactoryBottomSheet extends StatelessWidget {
  const FactoryBottomSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    return SafeArea(
      top: false,
      // A single scroll region for the handle + content together — nesting a
      // second SingleChildScrollView inside [child] doesn't get a bounded
      // height from this Column (mainAxisSize.min) and silently stops
      // scrolling, overflowing instead once content exceeds the sheet's
      // available height. Content that needs its own internal scrolling
      // (a long list) should size itself explicitly rather than relying on
      // this one.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: FactorySpacing.space2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [child] inside a [FactoryBottomSheet]. [isScrollControlled] should
/// be true for a sheet whose content can exceed half the screen height (a
/// filter sheet, a long form) — same contract as [showModalBottomSheet].
Future<T?> showFactoryBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (context) => FactoryBottomSheet(child: Builder(builder: builder)),
  );
}

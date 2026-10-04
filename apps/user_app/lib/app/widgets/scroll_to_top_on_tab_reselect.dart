import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/tab_reselect.dart';

/// Wrap a tab's root screen: tapping that tab in the bottom nav while it is
/// already showing scrolls the screen's (primary) scroll view back to the
/// top, and drops keyboard focus.
///
/// Lists inside the tab need no controller of their own: a vertical scroll
/// view without one attaches to the route's [PrimaryScrollController], which
/// is what this animates.
class ScrollToTopOnTabReselect extends ConsumerWidget {
  const ScrollToTopOnTabReselect({
    super.key,
    required this.tabIndex,
    required this.child,
  });

  final int tabIndex;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tabReselectProvider, (previous, next) {
      if (next == null || next.tabIndex != tabIndex) return;
      FocusManager.instance.primaryFocus?.unfocus();
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller == null || !controller.hasClients) return;
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
    return child;
  }
}

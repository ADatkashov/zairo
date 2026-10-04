import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired when the user taps the bottom-nav tab they are already on. Tab roots
/// listen (see `ScrollToTopOnTabReselect`) and scroll back to the top.
class TabReselect {
  const TabReselect(this.tabIndex, this.count);

  final int tabIndex;

  /// Distinguishes two taps on the same tab, which would otherwise be equal.
  final int count;
}

class TabReselectNotifier extends Notifier<TabReselect?> {
  @override
  TabReselect? build() => null;

  void reselect(int tabIndex) =>
      state = TabReselect(tabIndex, (state?.count ?? 0) + 1);
}

final tabReselectProvider = NotifierProvider<TabReselectNotifier, TabReselect?>(
  TabReselectNotifier.new,
);

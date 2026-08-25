import 'package:flutter/material.dart';

/// A themed confirm/alert dialog — color, radius and elevation already come
/// from `factory_theme.dart`'s `dialogTheme`; this fixes the title/message/
/// actions shape so screens stop hand-rolling `AlertDialog`.
///
/// The design system calls for this to render full-width and
/// bottom-anchored on mobile, centered/fixed-width on tablet and desktop —
/// that split needs its own presentation route, not just a themed
/// `AlertDialog`, so it's deferred to Phase 13 (Responsive Web). This is the
/// centered/fixed-width shape for now, correct on every width Factory
/// currently ships to.
class FactoryDialog extends StatelessWidget {
  const FactoryDialog({super.key, required this.title, required this.message, this.actions = const []});

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// Shows a [FactoryDialog]. Prefer this over a raw `showDialog` +
/// `AlertDialog` pair so every confirm/alert in the app shares one shape.
Future<T?> showFactoryDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  List<Widget> actions = const [],
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => FactoryDialog(title: title, message: message, actions: actions),
  );
}

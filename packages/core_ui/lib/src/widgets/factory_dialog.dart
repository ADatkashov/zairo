import 'package:flutter/material.dart';

/// A themed confirm/alert dialog — color, radius and elevation already come
/// from `factory_theme.dart`'s `dialogTheme`; this fixes the title/actions
/// shape so screens stop hand-rolling `AlertDialog`. Give it [message] for a
/// plain-text confirm ("Delete this vehicle?"); give it [content] instead
/// for a form dialog (a name field, a vertical picker) — exactly one of the
/// two should be set.
///
/// The design system calls for this to render full-width and
/// bottom-anchored on mobile, centered/fixed-width on tablet and desktop —
/// that split needs its own presentation route, not just a themed
/// `AlertDialog`, so it's deferred alongside the rest of the responsive
/// work. This is the centered/fixed-width shape for now, correct on every
/// width Factory currently ships to.
class FactoryDialog extends StatelessWidget {
  const FactoryDialog({super.key, required this.title, this.message, this.content, this.actions = const []})
      : assert(message != null || content != null, 'Provide either message or content');

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      // Taller than the screen (small phone, large text, keyboard open): scroll, don't overflow.
      scrollable: true,
      content: content ?? Text(message!),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// Shows a [FactoryDialog]. Prefer this over a raw `showDialog` +
/// `AlertDialog` pair so every confirm/alert/form dialog in the app shares
/// one shape.
Future<T?> showFactoryDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  List<Widget> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => FactoryDialog(title: title, message: message, content: content, actions: actions),
  );
}

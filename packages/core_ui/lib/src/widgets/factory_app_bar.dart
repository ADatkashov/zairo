import 'package:flutter/material.dart';

/// A thin canonical wrapper over [AppBar] so screens stop constructing
/// `AppBar(...)` directly — every visual choice (color, elevation, title
/// style) already comes from `factory_theme.dart`'s `appBarTheme`; this
/// exists so the design system's component inventory has one named entry
/// point rather than every screen re-deriving the same call.
class FactoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FactoryAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

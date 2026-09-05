import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import 'factory_icon_button.dart';

/// The entry point into Search & Discovery — distinct from
/// [FactoryTextField]: a leading search glyph instead of a label, a
/// `TextInputAction.search` keyboard action, and an optional trailing
/// filter trigger ([onFilterTap]) instead of a generic suffix slot.
class FactorySearchField extends StatelessWidget {
  const FactorySearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.filterSemanticLabel = 'Filters',
    this.filterActive = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;

  /// core_ui has no localization of its own — callers showing this in more
  /// than English should pass their own translated string here rather than
  /// relying on the English default (same convention as
  /// FactoryProviderCard's favorite labels).
  final String filterSemanticLabel;

  /// Tints the filter button the same way a selected [FactoryChip] reads —
  /// set this when [onFilterTap] leads to a filter set that isn't the
  /// default, so the field itself shows a filter is applied without the
  /// caller needing a separate indicator.
  final bool filterActive;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final baseTheme = Theme.of(context);

    // A locally bigger radius + soft shadow (Customer App Redesign board,
    // 2026-09-05) — scoped to this one widget via a Theme override rather
    // than raising `factory_theme.dart`'s shared InputDecorationTheme,
    // which every other text field in the app (login, forms, filter
    // sheet) also draws from.
    return Theme(
      data: baseTheme.copyWith(
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(
            borderRadius: FactoryRadius.xlRadius,
            borderSide: BorderSide(color: colors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: FactoryRadius.xlRadius,
            borderSide: BorderSide(color: colors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: FactoryRadius.xlRadius,
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: FactoryRadius.xlRadius,
        shadowColor: colors.text.withValues(alpha: 0.08),
        elevation: 2,
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.search_rounded, color: colors.textTertiary),
            suffixIcon: onFilterTap != null
                ? FactoryIconButton(
                    icon: Icons.tune_rounded,
                    onPressed: onFilterTap,
                    semanticLabel: filterSemanticLabel,
                    isActive: filterActive,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

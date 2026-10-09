import 'package:flutter/material.dart';

import 'factory_colors.dart';
import 'factory_app_profile.dart';
import 'factory_control_size.dart';
import 'factory_radius.dart';
import 'factory_typography.dart';

/// Builds the two Factory themes. Every vertical's app calls these directly
/// — `MaterialApp(theme: factoryLightTheme(), darkTheme: factoryDarkTheme())`
/// — rather than re-deriving a palette from `ColorScheme.fromSeed`, which is
/// how both apps looked before this package existed (stock Material purple).
/// [profile] picks the per-app temperament (card radius, row density); the
/// default is none, so existing callers are unchanged.
ThemeData factoryLightTheme({FactoryAppProfile? profile}) =>
    _factoryTheme(FactoryColors.light, profile);

ThemeData factoryDarkTheme({FactoryAppProfile? profile}) =>
    _factoryTheme(FactoryColors.dark, profile);

ThemeData _factoryTheme(FactoryColors colors, FactoryAppProfile? profile) {
  final brightness = colors.bg.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;

  // Start from a seeded scheme so every Material-internal role
  // (surfaceContainer variants, tertiary, inverse*, etc.) that Factory's
  // token set doesn't define still gets a sensible, on-brand value: then
  // overwrite exactly the roles Factory does define.
  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: brightness,
  ).copyWith(
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    primaryContainer: colors.primaryTint,
    onPrimaryContainer: colors.primaryStrong,
    secondary: colors.accent,
    onSecondary: brightness == Brightness.light ? colors.text : colors.onPrimary,
    secondaryContainer: colors.accentTint,
    surface: colors.surface,
    onSurface: colors.text,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.border,
    outlineVariant: colors.borderStrong,
    error: colors.error,
    // White on the light theme's deep red; near-black on the dark theme's pale
    // red (white there is only ~2.6:1).
    onError: brightness == Brightness.light ? Colors.white : colors.onPrimary,
  );

  final textTheme = FactoryTypography.textTheme(colors.text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.bg,
    dividerColor: colors.border,
    canvasColor: colors.bg,
    textTheme: textTheme,
    fontFamily: textTheme.bodyMedium?.fontFamily,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      titleTextStyle: textTheme.titleMedium,
      iconTheme: IconThemeData(color: colors.text),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: FactoryRadius.lgRadius,
        side: BorderSide(color: colors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
        disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.8),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(64, FactoryButtonHeight.md),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: FactoryRadius.mdRadius),
      ),
    ),
    // FilledButton defaults (Material3's own ColorScheme-driven style) don't
    // pick up the mdRadius/padding customization ElevatedButton gets above —
    // without this, the primary CTA button (e.g. Book) silently reverts to
    // stock Material shape on an otherwise fully Factory-themed screen.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
        disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.8),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(64, FactoryButtonHeight.md),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: FactoryRadius.mdRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(64, FactoryButtonHeight.md),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: FactoryRadius.mdRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primaryStrong,
        textStyle: textTheme.labelLarge,
        // 44×44 accessible minimum even though a text button reads visually
        // compact — Factory Design System, Component API §Button.
        minimumSize: const Size(44, 44),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border),
        minimumSize: const Size(44, 44),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: FactoryRadius.mdRadius,
        borderSide: BorderSide(color: colors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: FactoryRadius.mdRadius,
        borderSide: BorderSide(color: colors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: FactoryRadius.mdRadius,
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: FactoryRadius.mdRadius,
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.primary,
      side: BorderSide(color: colors.border, width: 1.5),
      shape: const StadiumBorder(),
      labelStyle: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      secondaryLabelStyle: textTheme.bodySmall?.copyWith(color: colors.onPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: FactoryRadius.lgRadius),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FactoryRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.bg),
      shape: RoundedRectangleBorder(borderRadius: FactoryRadius.mdRadius),
      behavior: SnackBarBehavior.floating,
    ),
    // Section tabs (e.g. the business-detail screen) — brand-coloured
    // indicator, readable inactive label, full-width hairline underneath.
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primaryStrong,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
      indicatorColor: colors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: colors.border,
      dividerHeight: 1,
      overlayColor: WidgetStatePropertyAll(colors.primaryTint.withValues(alpha: 0.5)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.surfaceAlt,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.onPrimary : colors.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.primary : colors.surfaceAlt,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : colors.borderStrong,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryTint,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
    ),
    extensions: [colors, if (profile != null) profile],
  );
}

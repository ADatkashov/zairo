import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';

/// The three-page welcome shown once, on the very first launch, before the
/// city prompt (see `CityOnboardingGate`). It says in three short beats what the
/// app is for — every service in one place, book online, see the price up
/// front — and never gates anything: "Skip" is always one tap away and the
/// pages hold no data, only illustrations built from the app's own components.
///
/// Pops when finished or skipped; opened by hand at `/welcome` with nothing to
/// pop to, it goes Home instead.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _pageCount = 3;

  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: FactoryMotion.resolve(context, FactoryMotion.base),
      curve: FactoryMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final titles = [l10n.welcomeTitle1, l10n.welcomeTitle2, l10n.welcomeTitle3];
    final bodies = [l10n.welcomeBody1, l10n.welcomeBody2, l10n.welcomeBody3];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space2, FactorySpacing.space4, 0),
                // Kept in the layout on the last page so nothing jumps.
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: FactoryButton(
                    label: l10n.welcomeSkip,
                    variant: FactoryButtonVariant.text,
                    onPressed: _finish,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space5),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _WelcomeArt(page: i),
                          const SizedBox(height: FactorySpacing.space8),
                          Text(titles[i], textAlign: TextAlign.center, style: textTheme.headlineSmall),
                          const SizedBox(height: FactorySpacing.space3),
                          Text(
                            bodies[i],
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space5),
              child: Column(
                children: [
                  _Dots(count: _pageCount, index: _page),
                  const SizedBox(height: FactorySpacing.space5),
                  FactoryButton(
                    label: _isLast ? l10n.welcomeStart : l10n.welcomeNext,
                    expand: true,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    // Decorative: the page content itself says where you are.
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: FactoryMotion.resolve(context, FactoryMotion.base),
              curve: FactoryMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? colors.primary : colors.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// The illustration of a welcome page, built only from the app's own parts:
/// category plates, real time slots, and the due-now / at-venue rows with
/// placeholder bars instead of amounts (no invented prices). Purely visual, so
/// hidden from assistive tech and from taps.
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          width: double.infinity,
          height: 264,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: FactoryRadius.xxlRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryTint, Color.alphaBlend(colors.primaryTint.withValues(alpha: 0.4), colors.surfaceAlt)],
            ),
          ),
          child: switch (page) {
            0 => const _CategoriesArt(),
            1 => const _SlotsArt(),
            _ => const _PaymentArt(),
          },
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.icon, required this.color, required this.tint, this.size = 80});

  final IconData icon;
  final Color color;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: FactoryRadius.xlRadius,
        border: Border.all(color: colors.surface, width: 3),
        boxShadow: context.factoryElevation(FactoryElevationLevel.md),
      ),
      child: Icon(icon, size: size * 0.45, color: color),
    );
  }
}

class _CategoriesArt extends StatelessWidget {
  const _CategoriesArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: _Plate(icon: Symbols.content_cut_rounded, color: colors.coral, tint: colors.coralTint),
        ),
        const SizedBox(width: FactorySpacing.space3),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: _Plate(icon: Symbols.directions_car_filled_rounded, color: colors.lavender, tint: colors.lavenderTint, size: 96),
        ),
        const SizedBox(width: FactorySpacing.space3),
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: _Plate(icon: Symbols.cleaning_services_rounded, color: colors.mint, tint: colors.mintTint),
        ),
      ],
    );
  }
}

class _SlotsArt extends StatelessWidget {
  const _SlotsArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(FactorySpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.xlRadius,
        border: Border.all(color: colors.border),
        boxShadow: context.factoryElevation(FactoryElevationLevel.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colors.primaryTint, borderRadius: FactoryRadius.mdRadius),
                child: Icon(Symbols.event_rounded, size: 20, color: colors.primary),
              ),
              const SizedBox(width: FactorySpacing.space3),
              _Bar(width: 96, color: colors.borderStrong),
            ],
          ),
          const SizedBox(height: FactorySpacing.space4),
          const Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              // All three states a slot can be in: taken, free, picked.
              FactoryTimeSlot(label: '10:00', state: FactoryTimeSlotState.unavailable),
              FactoryTimeSlot(label: '12:00'),
              FactoryTimeSlot(label: '14:30', state: FactoryTimeSlotState.selected),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentArt extends StatelessWidget {
  const _PaymentArt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    Widget row(String label, {bool highlight = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space3),
      color: highlight ? colors.primaryTint : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: highlight ? colors.primaryStrong : colors.textSecondary,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          _Bar(width: 52, color: highlight ? colors.primary : colors.borderStrong),
        ],
      ),
    );

    return Container(
      width: 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: FactoryRadius.xlRadius,
        border: Border.all(color: colors.border),
        boxShadow: context.factoryElevation(FactoryElevationLevel.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(l10n.bookingPayServicePrice),
          row(l10n.bookingPayDueNow, highlight: true),
          row(l10n.bookingPayAtVenue),
        ],
      ),
    );
  }
}

/// A placeholder for a value that is deliberately not shown.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 10,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(5)),
  );
}

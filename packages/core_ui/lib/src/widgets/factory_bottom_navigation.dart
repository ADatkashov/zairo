import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_elevation.dart';
import '../theme/factory_motion.dart';

/// One tab of a [FactoryBottomNavigation] bar. A single [icon] rather than
/// a separate selected/unselected pair — the Customer App Redesign board's
/// own `BottomNav.dc.html` renders one Material Symbols glyph per tab and
/// toggles solid-vs-outline via `font-variation-settings: 'FILL' <0|1>`
/// keyed off `isActive`, not two different icon glyphs ([_NavItem] applies
/// that same fill toggle below).
class FactoryNavDestination {
  const FactoryNavDestination({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// A small count on the icon (new messages, say); nothing is drawn at 0.
  /// Shown as "9+" from ten up.
  final int badgeCount;
}

/// One shortcut in the fan that opens from a [FactoryNavAction].
class FactoryNavQuickAction {
  const FactoryNavQuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;

  /// Shown under the round button and read by screen readers.
  final String label;
  final VoidCallback onTap;
}

/// The raised round action in the middle of a [FactoryBottomNavigation] (a
/// "+"). It is an action, not a tab: it never shows a selected state and
/// does not take an index in `destinations`.
///
/// With [quickActions] it opens a fan of those shortcuts above the bar (the
/// "+" turns into a "×"); without them a tap just calls [onTap].
class FactoryNavAction {
  const FactoryNavAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.quickActions = const [],
  }) : assert(onTap != null || quickActions.length > 0, 'an action needs an onTap or quick actions');

  final IconData icon;

  /// Read by screen readers; the button itself shows no text.
  final String label;
  final VoidCallback? onTap;
  final List<FactoryNavQuickAction> quickActions;
}

/// The customer app's tab bar — never more than four or five destinations
/// (the design system's own rule: every additional tab is tested against
/// "does this replace a search," and cut if not).
///
/// Renders as a floating, rounded pill bar (Customer App Redesign board,
/// 2026-09-05) rather than an edge-to-edge Material [NavigationBar] — the
/// active tab gets a `primaryTint` capsule instead of the bar's own
/// indicator. Kept as a bespoke `Row`/`InkWell` layout instead of
/// `NavigationBar` + `NavigationBarThemeData` because that API has no way to
/// inset the bar itself from the screen edges or round all four corners.
/// Public API (`destinations`/`selectedIndex`/`onDestinationSelected`) is
/// unchanged from the previous `NavigationBar`-backed version, so call sites
/// (`MainWrapper`) didn't need to change.
class FactoryBottomNavigation extends StatefulWidget {
  const FactoryBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.centerAction,
  });

  final List<FactoryNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Round action placed between the first and second half of
  /// [destinations]. Tab indexes reported by [onDestinationSelected] stay
  /// those of [destinations], the action does not shift them.
  final FactoryNavAction? centerAction;

  /// Width reserved for the action between the two halves of the tabs.
  static const double _actionSlot = 72;

  /// Diameter of the round action, and how far it rises above the bar.
  static const double _actionSize = 56;
  static const double _actionRise = 14;

  @override
  State<FactoryBottomNavigation> createState() => _FactoryBottomNavigationState();
}

class _FactoryBottomNavigationState extends State<FactoryBottomNavigation> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  late final AnimationController _fan = AnimationController(vsync: this, duration: FactoryMotion.base);

  bool get _fanOpen => _fan.status == AnimationStatus.forward || _fan.status == AnimationStatus.completed;

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  Future<void> _toggleFan() async {
    _fan.duration = FactoryMotion.resolve(context, FactoryMotion.base);
    if (_fanOpen) {
      await _fan.reverse();
      if (mounted && _fan.status == AnimationStatus.dismissed) _portal.hide();
    } else {
      _portal.show();
      await _fan.forward();
    }
  }

  void _onAction(FactoryNavAction action) {
    if (action.quickActions.isEmpty) {
      action.onTap?.call();
    } else {
      _toggleFan();
    }
  }

  Future<void> _pick(FactoryNavQuickAction quick) async {
    // Close first so the screen it opens is not stacked under an open fan.
    final closing = _toggleFan();
    quick.onTap();
    await closing;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final action = widget.centerAction;
    final destinations = widget.destinations;
    final split = destinations.length ~/ 2;

    Widget tab(int i, {required bool expand}) {
      final item = _NavItem(
        // Five or more tabs share ~70px each on a phone; the roomy
        // 12px side padding left a long label ("Бизнестер") ~50px
        // and it ellipsized to "Бизне…".
        dense: destinations.length > 4 || action != null,
        destination: destinations[i],
        isSelected: i == widget.selectedIndex,
        onTap: () => widget.onDestinationSelected(i),
      );
      // Equal shares around the action keep it exactly centred; without one,
      // Flexible (loose) lets four short labels keep their natural width.
      return expand ? Expanded(child: item) : Flexible(child: item);
    }

    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: context.factoryElevation(FactoryElevationLevel.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            if (action != null && i == split) const SizedBox(width: FactoryBottomNavigation._actionSlot),
            tab(i, expand: action != null),
          ],
        ],
      ),
    );

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: action == null
          ? bar
          : Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // The rise is part of this widget's own height, so the part of
                // the button above the bar still receives taps.
                Padding(
                  padding: const EdgeInsets.only(top: FactoryBottomNavigation._actionRise),
                  child: bar,
                ),
                OverlayPortal(
                  controller: _portal,
                  overlayChildBuilder: (_) => _Fan(
                    link: _link,
                    progress: _fan,
                    quickActions: action.quickActions,
                    // The dimmed page covers the real button, so the open fan
                    // carries its own undimmed copy (the "×") on top.
                    button: AnimatedBuilder(
                      animation: _fan,
                      builder: (context, _) => _ActionButton(
                        action: action,
                        turns: _fan.value * 0.125,
                        expanded: true,
                        onTap: _toggleFan,
                      ),
                    ),
                    onDismiss: _toggleFan,
                    onPick: _pick,
                  ),
                  child: CompositedTransformTarget(
                    link: _link,
                    child: AnimatedBuilder(
                      animation: _fan,
                      builder: (context, _) => _ActionButton(
                        action: action,
                        turns: action.quickActions.isEmpty ? 0 : _fan.value * 0.125,
                        expanded: action.quickActions.isEmpty ? null : _fanOpen,
                        onTap: () => _onAction(action),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The shortcuts, fanned out above the "+" over a dimmed page.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.link,
    required this.progress,
    required this.quickActions,
    required this.button,
    required this.onDismiss,
    required this.onPick,
  });

  final Widget button;
  final LayerLink link;
  final Animation<double> progress;
  final List<FactoryNavQuickAction> quickActions;
  final VoidCallback onDismiss;
  final ValueChanged<FactoryNavQuickAction> onPick;

  static const double _radius = 96;
  static const double _item = 52;
  static const double _labelWidth = 84;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final n = quickActions.length;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: AnimatedBuilder(
              animation: progress,
              builder: (_, _) => ColoredBox(color: Colors.black.withValues(alpha: 0.28 * progress.value)),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.center,
          followerAnchor: Alignment.bottomCenter,
          child: SizedBox(
            width: _radius * 2 + _labelWidth,
            height: _radius + _item + 28,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                final t = Curves.easeOutBack.transform(progress.value.clamp(0.0, 1.0));
                return Stack(
                  clipBehavior: Clip.none,
                  children: [for (var i = 0; i < n; i++) _positioned(context, colors, i, n, t)],
                );
              },
            ),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.center,
          followerAnchor: Alignment.center,
          child: Align(alignment: Alignment.center, widthFactor: 1, heightFactor: 1, child: button),
        ),
      ],
    );
  }

  Widget _positioned(BuildContext context, FactoryColors colors, int i, int n, double t) {
    // Spread over a 120deg arc centred straight up; one item sits at the top.
    const spread = 120.0;
    final deg = n == 1 ? 90.0 : 90 + spread / 2 - spread * i / (n - 1);
    final rad = deg * math.pi / 180;
    final dx = _radius * t * math.cos(rad);
    final dy = _radius * t * math.sin(rad);
    final item = quickActions[i];
    final width = _radius * 2 + _labelWidth;

    return Positioned(
      left: width / 2 + dx - _labelWidth / 2,
      bottom: dy - _item / 2 - 6,
      width: _labelWidth,
      child: Opacity(
        opacity: progress.value.clamp(0.0, 1.0),
        child: Semantics(
          button: true,
          label: item.label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(item),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _item,
                  height: _item,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    boxShadow: context.factoryElevation(FactoryElevationLevel.md),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryTint),
                    child: Icon(item.icon, size: 22, color: colors.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap, this.turns = 0, this.expanded});

  final FactoryNavAction action;
  final VoidCallback onTap;

  /// Fraction of a full turn the icon is rotated by: 0.125 turns "+" into "×".
  final double turns;

  /// Whether the fan is open (null when the action has no fan).
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Semantics(
      button: true,
      expanded: expanded,
      label: action.label,
      excludeSemantics: true,
      child: Container(
        width: FactoryBottomNavigation._actionSize + 12,
        height: FactoryBottomNavigation._actionSize + 12,
        // A ring in the surface colour makes the button look cut out of the
        // bar, and a soft halo of the brand colour ties it to the tab tint.
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.22), blurRadius: 20, spreadRadius: 1)],
        ),
        padding: const EdgeInsets.all(6),
        child: Material(
          color: colors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Transform.rotate(
              angle: turns * 2 * math.pi,
              child: Icon(action.icon, size: 28, color: colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dense,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final bool dense;
  final FactoryNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final color = isSelected ? colors.primary : colors.textTertiary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.badgeCount > 0
          ? '${destination.label}, ${destination.badgeCount}'
          : destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: FactoryMotion.fast,
            curve: FactoryMotion.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryTint : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        destination.icon,
                        fill: isSelected ? 1 : 0,
                        size: 22,
                        color: color,
                      ),
                      if (destination.badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: -9,
                          child: _CountBadge(count: destination.badgeCount),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 10, letterSpacing: 0, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // error (not coral) so the count keeps AA contrast with onError text.
        color: colors.error,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.surface, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

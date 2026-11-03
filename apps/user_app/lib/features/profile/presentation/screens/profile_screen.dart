import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/initials.dart';
import '../../../booking/presentation/screens/my_bookings_screen.dart' show upcomingBookingStatuses;
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/models/user_summary.dart';
import '../../../auth/presentation/auth_navigation.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../messaging/presentation/providers/message_seen_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../staff/presentation/providers/staff_cabinet_providers.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../loyalty/presentation/providers/loyalty_providers.dart';
import '../widgets/change_avatar_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: FactoryAppBar(
        title: l10n.profileTitle,
        actions: [
          if (authState.value != null) const NotificationBellButton(),
        ],
      ),
      body: authState.when(
        data: (user) => user == null ? const _LoggedOutView() : _LoggedInView(user: user),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric,
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedOutView extends ConsumerWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      // Scrolls when a large font on a small phone makes it taller than the screen.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FactorySpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryEmptyState(
              icon: Symbols.person_rounded,
              title: l10n.profileLoggedOutTitle,
              message: l10n.profileLoggedOutPrompt,
              actionLabel: l10n.loginTitle,
              onAction: () => pushAuthScreen(context, const LoginScreen()),
            ),
            // Phone-only builds: the phone form already registers, so no separate e-mail sign-up.
            if (ref.watch(emailSignInEnabledProvider))
              FactoryButton(
                label: l10n.profileCreateAccount,
                variant: FactoryButtonVariant.text,
                onPressed: () => pushAuthScreen(context, const RegisterScreen()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Name, e-mail and the avatar with a camera badge — on the page background,
/// not in a coloured block, so the person is the first thing seen and the
/// content below gets the room.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final avatarUrl = user.avatarUrl;
    final email = user.email;

    return Column(
      children: [
        Semantics(
          button: true,
          label: l10n.changeAvatarDialogTitle,
          child: GestureDetector(
            onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: avatarUrl != null),
            child: Stack(
              children: [
                FactoryAvatar(
                  initials: initialsFor(user.displayName),
                  size: FactoryAvatarSize.xl,
                  image: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.bg, width: 2),
                    ),
                    child: Icon(Symbols.photo_camera_rounded, size: 14, color: colors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FactorySpacing.space3),
        Text(user.displayName, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        if (email != null) ...[
          const SizedBox(height: FactorySpacing.space1),
          Text(
            email,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// A small tinted plate behind a row's icon, in the same category colours as
/// the Home tiles — so a list of rows stays scannable. Both colours null
/// gives the neutral plate.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.icon, {this.color, this.tint});

  final IconData icon;
  final Color? color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: tint ?? colors.surfaceAlt, borderRadius: FactoryRadius.mdRadius),
      child: Icon(icon, size: 18, color: color ?? colors.textSecondary),
    );
  }
}

/// A card of related rows with hairlines between them. No heading: three small
/// groups read lighter than one long titled list.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FactorySettingsGroup(dividerIndent: 60, children: children);
}

/// The three numbers people come to Profile for — bookings, favourites and
/// reward points — big and tappable, each opening its own list.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.cells});

  final List<_StatCell> cells;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return FactoryCard(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space1),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: colors.border),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.icon, required this.value, required this.label, required this.onTap});

  final IconData icon;

  /// null while it loads — shown as a dash, never as a misleading 0.
  final String? value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: FactoryRadius.mdRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: FactorySpacing.space3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: FactorySpacing.space1),
            // A big number must not break the cell: it shrinks before it wraps.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value ?? '—', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 2),
            // One line that shrinks rather than breaking in the middle of a
            // word (a long label in a narrow cell with a large font).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of a [_Group]: icon, label (with an optional hint under it) and, on
/// the right, an optional [trailing] widget (a badge), then a chevron when the
/// row opens something.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap});

  final Widget icon;
  final String label;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
          child: Row(
            children: [
              icon,
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.bodyLarge),
                    ?subtitle,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: FactorySpacing.space2), trailing!],
              if (onTap != null) Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final UserSummary user;

  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user.id;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    // Upcoming only: this stat opens the bookings list on that tab, so the number matches its rows.
    final bookingsCount = ref
        .watch(myBookingsProvider(userId))
        .value
        ?.where((b) => upcomingBookingStatuses.contains(b.status))
        .length;
    final favoritesCount = ref.watch(myFavoritesProvider(userId)).value?.length;
    final newMessages = ref.watch(newMessagesCountProvider);
    final loyalty = ref.watch(myLoyaltyProvider).value;
    final points = loyalty?.fold<int>(0, (sum, b) => sum + b.pointsBalance);
    final expiring = loyalty?.fold<int>(0, (sum, b) => sum + b.pointsExpiringSoon30d) ?? 0;
    // Only people who were added as staff somewhere get the cabinet entry.
    final staffMemberships = ref.watch(staffMembershipsProvider).value ?? const [];
    final staffPending = staffMemberships.fold<int>(0, (sum, m) => sum + m.pendingCount);

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        _ProfileHeader(user: user),
        const SizedBox(height: FactorySpacing.space5),
        _StatStrip(
          cells: [
            _StatCell(
              icon: Symbols.calendar_month_rounded,
              value: bookingsCount?.toString(),
              label: l10n.profileStatUpcoming,
              // The Bookings tab already exists; switching to it keeps the
              // bottom nav instead of stacking a second copy of the screen.
              onTap: () => context.go('/bookings'),
            ),
            _StatCell(
              icon: Symbols.favorite_rounded,
              value: favoritesCount?.toString(),
              label: l10n.profileStatFavorites,
              onTap: () => context.push(AppRoutes.favorites),
            ),
            _StatCell(
              icon: Symbols.redeem_rounded,
              value: points?.toString(),
              label: l10n.profileStatPoints,
              onTap: () => context.push(AppRoutes.rewards),
            ),
          ],
        ),
        // Only when it matters: points about to burn.
        if (expiring > 0)
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space2),
            child: InkWell(
              borderRadius: FactoryRadius.mdRadius,
              onTap: () => context.push(AppRoutes.rewards),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space2, vertical: FactorySpacing.space1),
                child: Row(
                  children: [
                    Icon(Symbols.schedule_rounded, size: 16, color: colors.warning),
                    const SizedBox(width: FactorySpacing.space2),
                    Expanded(
                      child: Text(
                        l10n.profileRewardsExpiring(expiring),
                        style: textTheme.bodySmall?.copyWith(color: colors.warning, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: FactorySpacing.space5),
        _Group(
          children: [
            if (staffMemberships.isNotEmpty)
              _ProfileRow(
                icon: _MenuIcon(Symbols.work_rounded, color: colors.primary, tint: colors.primaryTint),
                label: l10n.staffCabinetTitle,
                trailing: staffPending > 0
                    ? FactoryBadge(label: '$staffPending', variant: FactoryBadgeVariant.limited)
                    : null,
                onTap: () => context.push(AppRoutes.staffCabinet),
              ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.forum_rounded, color: colors.lavender, tint: colors.lavenderTint),
              label: l10n.messagesTitle,
              trailing: newMessages > 0 ? FactoryBadge(label: '$newMessages', variant: FactoryBadgeVariant.error) : null,
              onTap: () => context.push(AppRoutes.messages),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.confirmation_number_rounded, color: colors.mint, tint: colors.mintTint),
              label: l10n.loyaltyRedemptionsTitle,
              onTap: () => context.push(AppRoutes.redemptions),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space4),
        _Group(
          children: [
            _ProfileRow(
              icon: _MenuIcon(Symbols.person_rounded, color: colors.primary, tint: colors.primaryTint),
              label: l10n.profilePersonalData,
              // Nudge to fill in the birthday: it powers greetings and bonuses.
              subtitle: Text(
                user.birthDate == null ? l10n.editProfileBirthdayPrompt : l10n.profilePersonalSubtitle,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.credit_card_rounded, color: colors.primary, tint: colors.primaryTint),
              label: l10n.paymentCardsTitle,
              onTap: () => context.push(AppRoutes.paymentCards),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.directions_car_rounded, color: colors.lavender, tint: colors.lavenderTint),
              label: l10n.myVehiclesButton,
              onTap: () => context.push(AppRoutes.vehicles),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space4),
        _Group(
          children: [
            _ProfileRow(
              icon: const _MenuIcon(Symbols.settings_rounded),
              label: l10n.settingsTitle,
              subtitle: Text(
                l10n.profileSettingsSubtitle,
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
              onTap: () => context.push(AppRoutes.settings),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.support_agent_rounded, color: colors.mint, tint: colors.mintTint),
              label: l10n.supportTitle,
              onTap: () => context.push(AppRoutes.support),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space4),
        _LogOutButton(onPressed: () => _confirmLogOut(context, ref)),
        // Rarely needed, so a quiet link under the main actions, not a row.
        Center(
          child: FactoryButton(
            label: l10n.aboutTitle,
            variant: FactoryButtonVariant.text,
            onPressed: () => context.push(AppRoutes.about),
          ),
        ),
      ],
    );
  }
}

/// One tap on the log-out pill used to end the session at once; it now asks
/// first (the pill sits at the end of a long scroll, easy to hit by accident).
Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showFactoryDialog<bool>(
    context: context,
    title: l10n.profileLogOutConfirmTitle,
    message: l10n.profileLogOutConfirmMessage,
    actions: [
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: l10n.profileLogOutStayButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: l10n.profileLogOut,
          variant: FactoryButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    ],
  );
  if (confirmed == true) {
    ref.read(authControllerProvider.notifier).logout();
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;

    // A plain card with the destructive colour on the label only, as in the
    // reference: always at the end of the page, never louder than the content.
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: colors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: FactoryButtonHeight.md),
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.logout_rounded, size: 20, color: colors.error),
              const SizedBox(width: FactorySpacing.space2),
              Flexible(
                child: Text(
                  l10n.profileLogOut,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

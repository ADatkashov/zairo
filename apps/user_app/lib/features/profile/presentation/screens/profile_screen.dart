import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/initials.dart';
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
          IconButton(
            icon: const Icon(Symbols.settings_rounded),
            tooltip: l10n.settingsButtonTooltip,
            onPressed: () => context.push(AppRoutes.settings),
          ),
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

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
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

/// Brand-colour header with an ambient brass glow behind the avatar — the
/// same deep-green block as the Home availability hero, so the person is the
/// first thing seen and the app reads as one family. Text inside it uses
/// `onPrimary`, which flips to near-black on the bright mint of the dark theme.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6, horizontal: FactorySpacing.space4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryStrong, colors.primary],
        ),
        borderRadius: radius,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -90,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [colors.accent.withValues(alpha: 0.42), colors.accent.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A menu row's icon on a small tinted plate, in the same category colours as
/// the Home tiles — so a long list of identical grey outlines becomes scannable.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.icon, {this.color, this.tint});

  final IconData icon;

  /// Icon and plate colours; both null gives the neutral plate.
  final Color? color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: tint ?? colors.surfaceAlt, borderRadius: FactoryRadius.mdRadius),
      child: Icon(icon, size: 20, color: color ?? colors.textSecondary),
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final UserSummary user;

  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user.id;
    final displayName = user.displayName;
    final email = user.email;
    final avatarUrl = user.avatarUrl;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final bookingsCount = ref.watch(myBookingsProvider(userId)).value?.length;
    final favoritesCount = ref.watch(myFavoritesProvider(userId)).value?.length;
    // Only people who were added as staff somewhere get the cabinet entry.
    final staffMemberships = ref.watch(staffMembershipsProvider).value ?? const [];
    final staffPending = staffMemberships.fold<int>(0, (sum, m) => sum + m.pendingCount);

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        _ProfileHeader(
          child: Column(
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: l10n.changeAvatarDialogTitle,
                  child: GestureDetector(
                  onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: avatarUrl != null),
                  child: Stack(
                    children: [
                      // A ring in onPrimary lifts the avatar off the green header.
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: colors.onPrimary, shape: BoxShape.circle),
                        child: FactoryAvatar(
                          initials: initialsFor(displayName),
                          size: FactoryAvatarSize.xl,
                          image: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.bg, width: 2),
                          ),
                          child: Icon(Icons.edit, size: 14, color: colors.onPrimary),
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              Center(
                child: Text(displayName, style: textTheme.headlineSmall?.copyWith(color: colors.onPrimary), textAlign: TextAlign.center),
              ),
              const SizedBox(height: FactorySpacing.space1),
              if (email != null)
                Center(
                  child: Text(email, style: textTheme.bodyMedium?.copyWith(color: colors.onPrimary.withValues(alpha: 0.82))),
                ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space6),
        FactoryCard(
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: FactoryRadius.mdRadius,
                    // The Bookings tab already exists; switching to it keeps the
                    // bottom nav instead of stacking a second copy of the screen.
                    onTap: () => context.go('/bookings'),
                    child: FactoryStatTile(
                      value: bookingsCount?.toString() ?? '—',
                      label: l10n.myBookingsTitle,
                      icon: Symbols.calendar_month_rounded,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: colors.border),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: FactoryRadius.mdRadius,
                    onTap: () => context.push(AppRoutes.favorites),
                    child: FactoryStatTile(
                      value: favoritesCount?.toString() ?? '—',
                      label: l10n.myFavoritesTitle,
                      icon: Symbols.favorite_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (staffMemberships.isNotEmpty) ...[
          const SizedBox(height: FactorySpacing.space6),
          FactorySelectableTile(
            title: l10n.staffCabinetTitle,
            leading: _MenuIcon(Symbols.work_rounded, color: colors.primary, tint: colors.primaryTint),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (staffPending > 0) ...[
                  FactoryBadge(label: '$staffPending', variant: FactoryBadgeVariant.limited),
                  const SizedBox(width: FactorySpacing.space2),
                ],
                Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
            onTap: () => context.push(AppRoutes.staffCabinet),
          ),
        ],
        const SizedBox(height: FactorySpacing.space6),
        FactorySelectableTile(
          title: l10n.editProfileButton,
          // Nudge to fill in the birthday: it powers greetings and bonuses.
          subtitle: user.birthDate == null
              ? Text(l10n.editProfileBirthdayPrompt, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))
              : null,
          leading: _MenuIcon(Symbols.edit_rounded, color: colors.primary, tint: colors.primaryTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.editProfile),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.profileSectionActivity),
        const SizedBox(height: FactorySpacing.space3),
        // The stat tile above also opens Favorites, but it reads as a counter,
        // not a button — a list row is where people look for it.
        FactorySelectableTile(
          title: l10n.myFavoritesTitle,
          leading: _MenuIcon(Symbols.favorite_rounded, color: colors.coral, tint: colors.coralTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.favorites),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.messagesTitle,
          leading: _MenuIcon(Symbols.forum_rounded, color: colors.lavender, tint: colors.lavenderTint),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ref.watch(newMessagesCountProvider) > 0) ...[
                FactoryBadge(label: '${ref.watch(newMessagesCountProvider)}', variant: FactoryBadgeVariant.error),
                const SizedBox(width: FactorySpacing.space2),
              ],
              Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
          onTap: () => context.push(AppRoutes.messages),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.myRewardsTitle,
          leading: _MenuIcon(Symbols.redeem_rounded, color: colors.accentInk, tint: colors.accentTint.withValues(alpha: 0.45)),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.rewards),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.loyaltyRedemptionsTitle,
          leading: _MenuIcon(Symbols.confirmation_number_rounded, color: colors.mint, tint: colors.mintTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.redemptions),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.paymentCardsTitle,
          leading: _MenuIcon(Symbols.credit_card_rounded, color: colors.primary, tint: colors.primaryTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.paymentCards),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.myVehiclesButton,
          leading: _MenuIcon(Symbols.directions_car_rounded, color: colors.lavender, tint: colors.lavenderTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.vehicles),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.profileSectionHelp),
        const SizedBox(height: FactorySpacing.space3),
        FactorySelectableTile(
          title: l10n.supportTitle,
          leading: _MenuIcon(Symbols.support_agent_rounded, color: colors.mint, tint: colors.mintTint),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.support),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.aboutTitle,
          leading: _MenuIcon(Symbols.info_rounded),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.about),
        ),
        const SizedBox(height: FactorySpacing.space6),
        _LogOutButton(onPressed: () => _confirmLogOut(context, ref)),
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

/// The Customer App Redesign board's tinted-pill log-out action — coral
/// text/icon on a coral-tint fill, distinct from every other Factory
/// button variant (which are all neutral or primary-colored), so this is
/// its own small widget rather than a new [FactoryButtonVariant].
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.coralTint,
        shape: FactoryRadius.pill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: FactoryButtonHeight.md,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.logout_rounded, size: 18, color: colors.error),
                const SizedBox(width: 8),
                Text(l10n.profileLogOut, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

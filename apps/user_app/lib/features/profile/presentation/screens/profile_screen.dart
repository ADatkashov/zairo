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
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
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
        data: (user) => user == null
            ? const _LoggedOutView()
            : _LoggedInView(user: user),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
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

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        const SizedBox(height: FactorySpacing.space4),
        Center(
          child: GestureDetector(
            onTap: () => showChangeAvatarDialog(context, hasCurrentAvatar: avatarUrl != null),
            child: Stack(
              children: [
                FactoryAvatar(
                  initials: initialsFor(displayName),
                  size: FactoryAvatarSize.xl,
                  image: avatarUrl != null ? NetworkImage(avatarUrl) : null,
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
        const SizedBox(height: FactorySpacing.space3),
        Center(
          child: Text(
            displayName,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: FactorySpacing.space1),
        if (email != null)
          Center(
            child: Text(
              email,
              style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
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
        const SizedBox(height: FactorySpacing.space6),
        FactorySelectableTile(
          title: l10n.editProfileButton,
          // Nudge to fill in the birthday: it powers greetings and bonuses.
          subtitle: user.birthDate == null
              ? Text(
                  l10n.editProfileBirthdayPrompt,
                  style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                )
              : null,
          leading: Icon(Symbols.edit_rounded, color: colors.textSecondary),
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
          leading: Icon(Symbols.favorite_rounded, color: colors.textSecondary),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.favorites),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.messagesTitle,
          leading: Icon(Symbols.forum_rounded, color: colors.textSecondary),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.messages),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.myRewardsTitle,
          leading: Icon(Symbols.redeem_rounded, color: colors.textSecondary),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.rewards),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.loyaltyRedemptionsTitle,
          leading: Icon(Symbols.confirmation_number_rounded, color: colors.textSecondary),
          trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => context.push(AppRoutes.redemptions),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.myVehiclesButton,
          leading: Icon(
            Symbols.directions_car_rounded,
            color: colors.textSecondary,
          ),
          trailing: Icon(
            Symbols.chevron_right_rounded,
            color: colors.textTertiary,
          ),
          onTap: () => context.push(AppRoutes.vehicles),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.profileSectionHelp),
        const SizedBox(height: FactorySpacing.space3),
        FactorySelectableTile(
          title: l10n.supportTitle,
          leading: Icon(
            Symbols.support_agent_rounded,
            color: colors.textSecondary,
          ),
          trailing: Icon(
            Symbols.chevron_right_rounded,
            color: colors.textTertiary,
          ),
          onTap: () => context.push(AppRoutes.support),
        ),
        const SizedBox(height: FactorySpacing.space2),
        FactorySelectableTile(
          title: l10n.aboutTitle,
          leading: Icon(Symbols.info_rounded, color: colors.textSecondary),
          trailing: Icon(
            Symbols.chevron_right_rounded,
            color: colors.textTertiary,
          ),
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
                Icon(Symbols.logout_rounded, size: 18, color: colors.coral),
                const SizedBox(width: 8),
                Text(
                  l10n.profileLogOut,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.coral),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

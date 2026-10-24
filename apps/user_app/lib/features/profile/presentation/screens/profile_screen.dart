import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../city/presentation/providers/city_providers.dart';
import '../../../messaging/presentation/providers/message_seen_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../staff/presentation/providers/staff_cabinet_providers.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../loyalty/data/models/loyalty.dart';
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

/// A titled card of rows: the title sits above the card, the rows share it
/// with hairlines between them.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(FactorySpacing.space1, 0, FactorySpacing.space1, FactorySpacing.space2),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        FactorySettingsGroup(dividerIndent: 60, children: children),
      ],
    );
  }
}

/// One row of a [_Section]: icon, label (with an optional hint under it) and,
/// on the right, either a [value] ("12 May 2023", "3") or a [trailing] widget,
/// then a chevron when the row opens something.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final Widget? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodyLarge),
        ?subtitle,
      ],
    );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                icon,
                const SizedBox(width: FactorySpacing.space3),
                if (value == null)
                  Expanded(child: labelColumn)
                else ...[
                  // The label takes the width it needs (never more than 60 %,
                  // so a long one wraps between words), the value the rest.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
                    child: labelColumn,
                  ),
                  const SizedBox(width: FactorySpacing.space2),
                  Expanded(
                    child: Text(
                      value!,
                      style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: FactorySpacing.space2), trailing!],
                if (onTap != null) Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Russian", "English", "Kazakh" — each language in its own script, the way the
/// language picker in Settings names them.
String _languageName(String code) => switch (code) {
  'ru' => 'Русский',
  'kk' => 'Қазақша',
  _ => 'English',
};

class _LoggedInView extends ConsumerWidget {
  final UserSummary user;

  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user.id;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final bookingsCount = ref.watch(myBookingsProvider(userId)).value?.length;
    final favoritesCount = ref.watch(myFavoritesProvider(userId)).value?.length;
    final newMessages = ref.watch(newMessagesCountProvider);
    final city = ref.watch(userCurrentCityProvider).value;
    final birthDate = user.birthDate;
    // Only people who were added as staff somewhere get the cabinet entry.
    final staffMemberships = ref.watch(staffMembershipsProvider).value ?? const [];
    final staffPending = staffMemberships.fold<int>(0, (sum, m) => sum + m.pendingCount);

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        _ProfileHeader(user: user),
        const SizedBox(height: FactorySpacing.space6),
        // The e-mail is already under the name above, so it isn't repeated here.
        _Section(
          title: l10n.profileSectionData,
          children: [
            _ProfileRow(
              icon: const _MenuIcon(Symbols.cake_rounded),
              label: l10n.editProfileBirthdayLabel,
              value: birthDate == null ? l10n.editProfileBirthdayNotSet : DateFormat.yMMMMd(languageCode).format(birthDate),
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            if (city != null)
              _ProfileRow(
                icon: const _MenuIcon(Symbols.location_on_rounded),
                label: l10n.profileCityLabel,
                value: city.nameFor(languageCode),
                onTap: () => context.push(AppRoutes.citySelection),
              ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.edit_rounded, color: colors.primary, tint: colors.primaryTint),
              label: l10n.editProfileButton,
              // Nudge to fill in the birthday: it powers greetings and bonuses.
              subtitle: birthDate == null
                  ? Text(l10n.editProfileBirthdayPrompt, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))
                  : null,
              onTap: () => context.push(AppRoutes.editProfile),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space5),
        _Section(
          title: l10n.profileSectionActivity,
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
              icon: _MenuIcon(Symbols.calendar_month_rounded, color: colors.primary, tint: colors.primaryTint),
              label: l10n.myBookingsTitle,
              value: bookingsCount?.toString(),
              // The Bookings tab already exists; switching to it keeps the
              // bottom nav instead of stacking a second copy of the screen.
              onTap: () => context.go('/bookings'),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.favorite_rounded, color: colors.coral, tint: colors.coralTint),
              label: l10n.myFavoritesTitle,
              value: favoritesCount?.toString(),
              onTap: () => context.push(AppRoutes.favorites),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.forum_rounded, color: colors.lavender, tint: colors.lavenderTint),
              label: l10n.messagesTitle,
              trailing: newMessages > 0 ? FactoryBadge(label: '$newMessages', variant: FactoryBadgeVariant.error) : null,
              onTap: () => context.push(AppRoutes.messages),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.redeem_rounded, color: colors.accentInk, tint: colors.accentTint.withValues(alpha: 0.45)),
              label: l10n.myRewardsTitle,
              // The one number people come back for: how many points they have, and whether any are about to burn.
              subtitle: _rewardsSummary(ref, l10n, textTheme, colors),
              onTap: () => context.push(AppRoutes.rewards),
            ),
            _ProfileRow(
              icon: _MenuIcon(Symbols.confirmation_number_rounded, color: colors.mint, tint: colors.mintTint),
              label: l10n.loyaltyRedemptionsTitle,
              onTap: () => context.push(AppRoutes.redemptions),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space5),
        _Section(
          title: l10n.settingsTitle,
          children: [
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
            _ProfileRow(
              icon: const _MenuIcon(Symbols.shield_lock_rounded),
              label: l10n.securityTitle,
              onTap: () => context.push(AppRoutes.securitySettings),
            ),
            _ProfileRow(
              icon: const _MenuIcon(Symbols.language_rounded),
              label: l10n.languageSectionTitle,
              value: _languageName(languageCode),
              onTap: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space5),
        _Section(
          title: l10n.profileSectionHelp,
          children: [
            _ProfileRow(
              icon: _MenuIcon(Symbols.support_agent_rounded, color: colors.mint, tint: colors.mintTint),
              label: l10n.supportTitle,
              onTap: () => context.push(AppRoutes.support),
            ),
            _ProfileRow(
              icon: const _MenuIcon(Symbols.info_rounded),
              label: l10n.aboutTitle,
              onTap: () => context.push(AppRoutes.about),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space5),
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

/// "320 points · 2 businesses" under My rewards, plus a warning when some expire within 30 days. Nothing while it
/// loads, on error, or before the first points — it is a hint, not worth a state of its own.
Widget? _rewardsSummary(WidgetRef ref, AppLocalizations l10n, TextTheme textTheme, FactoryColors colors) {
  final businesses = ref.watch(myLoyaltyProvider).value ?? const <LoyaltyBusinessSummary>[];
  final active = businesses.where((b) => b.pointsBalance > 0).toList();
  if (active.isEmpty) return null;
  final points = active.fold<int>(0, (sum, b) => sum + b.pointsBalance);
  final expiring = businesses.fold<int>(0, (sum, b) => sum + b.pointsExpiringSoon30d);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.profileRewardsSummary(points, active.length),
        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      ),
      if (expiring > 0)
        Text(
          l10n.profileRewardsExpiring(expiring),
          style: textTheme.bodySmall?.copyWith(color: colors.warning, fontWeight: FontWeight.w700),
        ),
    ],
  );
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

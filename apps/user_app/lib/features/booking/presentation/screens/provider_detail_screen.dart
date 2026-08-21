import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../beauty/data/beauty_exception.dart';
import '../../../beauty/data/models/master.dart';
import '../../../beauty/presentation/providers/beauty_providers.dart';
import '../../../beauty/presentation/screens/master_portfolio_screen.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../maps/presentation/screens/mock_map_screen.dart';
import '../../../payments/data/payment_exception.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../data/booking_exception.dart';
import '../providers/booking_providers.dart';

class ProviderDetailScreen extends ConsumerStatefulWidget {
  final ProviderSearchResult provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  String? _selectedServiceId;
  String? _selectedSlotId;
  String? _selectedMasterId;
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final slotsAsync = ref.watch(availabilitySlotsProvider(widget.provider.id));
    // Only the beauty vertical has masters; other verticals never touch
    // this provider, so the section below simply doesn't render for them.
    final mastersAsync = widget.provider.vertical == 'beauty'
        ? ref.watch(mastersProvider(widget.provider.id))
        : const AsyncValue.data(<Master>[]);
    final masters = mastersAsync.value ?? const <Master>[];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(widget.provider.name),
        actions: [FavoriteButton(providerId: widget.provider.id)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FactoryBadge(label: _capitalize(widget.provider.vertical)),
                if (widget.provider.hasOpenAvailability)
                  FactoryBadge(label: l10n.availableTodayLabel, variant: FactoryBadgeVariant.available),
                if (widget.provider.distanceKm != null)
                  Text(
                    l10n.providerDistanceAway(widget.provider.distanceKm!.toStringAsFixed(1)),
                    style: FactoryTypography.mono(size: 12, color: colors.textTertiary),
                  ),
              ],
            ),
            if (widget.provider.latitude != null && widget.provider.longitude != null) ...[
              const SizedBox(height: FactorySpacing.space3),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.viewOnMapButton),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MockMapScreen(
                        providerName: widget.provider.name,
                        latitude: widget.provider.latitude!,
                        longitude: widget.provider.longitude!,
                        distanceKm: widget.provider.distanceKm,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (masters.isNotEmpty) ...[
              const SizedBox(height: FactorySpacing.space6),
              Text(l10n.mastersSectionTitle, style: textTheme.titleMedium),
              const SizedBox(height: FactorySpacing.space3),
              ...masters.map(
                (master) => Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                  child: _MasterOption(
                    master: master,
                    selected: _selectedMasterId == master.id,
                    onTap: () => setState(() => _selectedMasterId = master.id),
                    onViewPortfolio: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MasterPortfolioScreen(
                          masterId: master.id,
                          masterName: master.displayName,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: FactorySpacing.space6),
            Text(l10n.servicesSectionTitle, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space2),
            ...widget.provider.services.map(
              (service) => ServiceRow(
                title: service.title,
                metaText: l10n.serviceDurationMinutes(service.durationMinutes),
                price: service.price,
                selected: _selectedServiceId == service.id,
                onTap: () => setState(() => _selectedServiceId = service.id),
              ),
            ),
            const SizedBox(height: FactorySpacing.space6),
            Text(l10n.availableTimesSectionTitle, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space3),
            slotsAsync.when(
              data: (slots) {
                final openSlots = slots.where((s) => s.isOpen).toList();
                if (openSlots.isEmpty) {
                  return FactoryEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: l10n.noOpenTimesTitle,
                    message: l10n.noOpenTimesMessage,
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: openSlots
                      .map(
                        (slot) => FactoryTimeSlot(
                          label: formatMonthDayTime(l10n, slot.startsAt.toLocal()),
                          state: _selectedSlotId == slot.id
                              ? FactoryTimeSlotState.selected
                              : FactoryTimeSlotState.available,
                          onTap: () => setState(() => _selectedSlotId = slot.id),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => FactoryErrorState(
                message: l10n.errorAvailabilityLoadFailed,
                onRetry: () => ref.invalidate(availabilitySlotsProvider(widget.provider.id)),
              ),
            ),
            const SizedBox(height: FactorySpacing.space6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selectedServiceId != null &&
                        _selectedSlotId != null &&
                        (masters.isEmpty || _selectedMasterId != null) &&
                        !_isBooking)
                    ? _book
                    : null,
                child: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.bookButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book() async {
    // Reads authControllerProvider.future rather than a synchronous
    // .value snapshot: if this is the first time anything has touched
    // authControllerProvider (e.g. the user never opened the Profile tab),
    // .value would race the AsyncNotifier's still-in-flight session
    // restore and wrongly read as "logged out" — caught by a flaky
    // widget test, see provider_detail_screen_test.dart.
    setState(() => _isBooking = true);
    final currentUser = await ref.read(authControllerProvider.future);
    if (currentUser == null) {
      setState(() => _isBooking = false);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final service = widget.provider.services.firstWhere((s) => s.id == _selectedServiceId);
    try {
      // A master was selected only when this provider has a beauty master
      // directory (see the Book button's enable condition above) — route
      // through the beauty booking endpoint so the "master offers this
      // service" rule is enforced server-side; otherwise use Core's plain
      // booking flow, unchanged from before masters existed.
      final booking = _selectedMasterId != null
          ? await ref.read(beautyApiProvider).createBeautyBooking(
                userId: currentUser.id,
                masterId: _selectedMasterId!,
                serviceId: service.id,
                availabilitySlotId: _selectedSlotId!,
                totalPrice: service.price,
              )
          : await ref.read(bookingApiProvider).createBooking(
                userId: currentUser.id,
                serviceId: service.id,
                availabilitySlotId: _selectedSlotId!,
                totalPrice: service.price,
              );

      // Charged right after booking creation, in the same flow — see
      // SESSION_NOTES.md for why this isn't gated behind a webhook yet
      // (no real payment provider/webhook exists; the mock resolves
      // synchronously, so there's nothing async to wait on).
      String message = l10n.bookingConfirmed;
      try {
        final payment = await ref.read(paymentsApiProvider).createPayment(booking.id);
        message = payment.status == 'SUCCEEDED'
            ? l10n.bookingConfirmedAndPaid
            : l10n.bookingConfirmedPaymentStatus(payment.status.toLowerCase());
      } on PaymentException catch (e) {
        message = l10n.bookingConfirmedButError(e.localizedMessage(l10n));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } on BeautyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorBookingGeneric(e.toString()))));
      setState(() => _isBooking = false);
    }
  }
}

class _MasterOption extends StatelessWidget {
  const _MasterOption({
    required this.master,
    required this.selected,
    required this.onTap,
    required this.onViewPortfolio,
  });

  final Master master;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onViewPortfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.mdRadius,
        child: Container(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          decoration: BoxDecoration(
            color: selected ? colors.primaryTint : colors.surface,
            borderRadius: FactoryRadius.mdRadius,
            border: Border.all(color: selected ? colors.primary : colors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              FactoryAvatar(
                initials: _initialsFor(master.displayName),
                image: master.photoUrl != null ? NetworkImage(master.photoUrl!) : null,
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(master.displayName, style: textTheme.titleSmall),
                    if (master.bio != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        master.bio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                Icon(Icons.check_circle_rounded, size: 20, color: colors.primary),
                const SizedBox(width: FactorySpacing.space1),
              ],
              IconButton(
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: l10n.viewPortfolioTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  foregroundColor: colors.textSecondary,
                ),
                onPressed: onViewPortfolio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auto/data/auto_exception.dart';
import '../../../auto/data/models/mechanic.dart';
import '../../../auto/data/models/vehicle.dart';
import '../../../auto/presentation/providers/auto_providers.dart';
import '../../../auto/presentation/widgets/add_vehicle_dialog.dart';
import '../../../beauty/data/beauty_exception.dart';
import '../../../beauty/data/models/master.dart';
import '../../../beauty/presentation/providers/beauty_providers.dart';
import '../../../beauty/presentation/screens/master_portfolio_screen.dart';
import '../../../cleaning/data/cleaning_exception.dart';
import '../../../cleaning/data/models/cleaner.dart';
import '../../../cleaning/presentation/providers/cleaning_providers.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/data/models/service_summary.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../loyalty/presentation/widgets/loyalty_entry_tile.dart';
import '../../../maps/presentation/screens/provider_map_screen.dart';
import '../../../payments/data/payment_exception.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../staff/data/models/staff.dart';
import '../../../staff/data/staff_exception.dart';
import '../../../staff/presentation/providers/staff_providers.dart';
import '../../data/booking_exception.dart';
import '../../data/models/booking.dart';
import '../providers/booking_providers.dart';

/// Categories with their own hardcoded staff module (Master/Mechanic/
/// Cleaner) — every other category falls back to the generic `staff`
/// module below, so a platform admin's brand-new category is bookable
/// with a specific staff member immediately, with no app release.
const _verticalsWithDedicatedStaffModule = {'beauty', 'auto', 'cleaning'};

class ProviderDetailScreen extends ConsumerStatefulWidget {
  final ProviderSearchResult provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  ConsumerState<ProviderDetailScreen> createState() =>
      _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  String? _selectedServiceId;
  String? _selectedSlotId;
  String? _selectedMasterId;
  String? _selectedMechanicId;
  String? _selectedVehicleId;
  String? _selectedCleanerId;
  String? _selectedStaffId;
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final slotsAsync = ref.watch(availabilitySlotsProvider(widget.provider.id));
    final currentUser = ref.watch(authControllerProvider).value;
    // Only the beauty vertical has masters; other verticals never touch
    // this provider, so the section below simply doesn't render for them.
    final mastersAsync = widget.provider.vertical == 'beauty'
        ? ref.watch(mastersProvider(widget.provider.id))
        : const AsyncValue.data(<Master>[]);
    final masters = mastersAsync.value ?? const <Master>[];
    // Same reasoning for the auto vertical's mechanics.
    final mechanicsAsync = widget.provider.vertical == 'auto'
        ? ref.watch(mechanicsProvider(widget.provider.id))
        : const AsyncValue.data(<Mechanic>[]);
    final mechanics = mechanicsAsync.value ?? const <Mechanic>[];
    // Vehicles are owned by the current user, not the provider — only
    // fetchable once logged in (an anonymous caller has none to select).
    final vehiclesAsync =
        (widget.provider.vertical == 'auto' && currentUser != null)
        ? ref.watch(vehiclesProvider(currentUser.id))
        : const AsyncValue.data(<Vehicle>[]);
    final vehicles = vehiclesAsync.value ?? const <Vehicle>[];
    final requiresVehicleSelection =
        mechanics.isNotEmpty && currentUser != null;
    // Same reasoning as masters/mechanics, for the cleaning vertical's cleaners.
    final cleanersAsync = widget.provider.vertical == 'cleaning'
        ? ref.watch(cleanersProvider(widget.provider.id))
        : const AsyncValue.data(<Cleaner>[]);
    final cleaners = cleanersAsync.value ?? const <Cleaner>[];
    // Any category without its own dedicated staff module falls back to
    // the generic `staff` module — see _verticalsWithDedicatedStaffModule.
    final staffAsync =
        !_verticalsWithDedicatedStaffModule.contains(widget.provider.vertical)
        ? ref.watch(staffProvider(widget.provider.id))
        : const AsyncValue.data(<Staff>[]);
    final staffMembers = staffAsync.value ?? const <Staff>[];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: widget.provider.name,
        actions: [FavoriteButton(providerId: widget.provider.id)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: FactoryRadius.xlRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.primaryTint, colors.surfaceAlt],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        switch (widget.provider.vertical) {
                          'auto' => Symbols.directions_car_filled_rounded,
                          'cleaning' => Symbols.cleaning_services_rounded,
                          _ => Symbols.content_cut_rounded,
                        },
                        size: 48,
                        color: colors.primaryStrong.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.provider.averageRating != null)
                        FactoryRatingLabel(
                          rating: widget.provider.averageRating!,
                          reviewCount: widget.provider.reviewCount,
                          semanticLabel: widget.provider.reviewCount == null
                              ? l10n.ratingSemanticLabel(
                                  widget.provider.averageRating!
                                      .toStringAsFixed(1),
                                )
                              : l10n.ratingSemanticLabelWithReviews(
                                  widget.provider.averageRating!
                                      .toStringAsFixed(1),
                                  widget.provider.reviewCount!,
                                ),
                        ),
                      FactoryBadge(
                        label: _capitalize(widget.provider.vertical),
                      ),
                      if (widget.provider.hasOpenAvailability)
                        FactoryBadge(
                          label: l10n.availableTodayLabel,
                          variant: FactoryBadgeVariant.available,
                        ),
                      if (widget.provider.distanceKm != null)
                        Text(
                          l10n.providerDistanceAway(
                            widget.provider.distanceKm!.toStringAsFixed(1),
                          ),
                          style: FactoryTypography.mono(
                            size: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (widget.provider.latitude != null &&
                      widget.provider.longitude != null) ...[
                    const SizedBox(height: FactorySpacing.space3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FactoryButton(
                        variant: FactoryButtonVariant.secondary,
                        icon: Symbols.map_rounded,
                        label: l10n.viewOnMapButton,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProviderMapScreen(
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
                  const SizedBox(height: FactorySpacing.space3),
                  LoyaltyEntryTile(
                    providerId: widget.provider.id,
                    providerName: widget.provider.name,
                  ),
                  if (masters.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    Text(
                      l10n.mastersSectionTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    ...masters.map(
                      (master) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: FactorySpacing.space2,
                        ),
                        child: _MasterOption(
                          master: master,
                          selected: _selectedMasterId == master.id,
                          onTap: () =>
                              setState(() => _selectedMasterId = master.id),
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
                  if (mechanics.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    Text(
                      l10n.mechanicsSectionTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    ...mechanics.map(
                      (mechanic) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: FactorySpacing.space2,
                        ),
                        child: _MechanicOption(
                          mechanic: mechanic,
                          selected: _selectedMechanicId == mechanic.id,
                          onTap: () =>
                              setState(() => _selectedMechanicId = mechanic.id),
                        ),
                      ),
                    ),
                  ],
                  if (cleaners.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    Text(
                      l10n.cleanersSectionTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    ...cleaners.map(
                      (cleaner) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: FactorySpacing.space2,
                        ),
                        child: _CleanerOption(
                          cleaner: cleaner,
                          selected: _selectedCleanerId == cleaner.id,
                          onTap: () =>
                              setState(() => _selectedCleanerId = cleaner.id),
                        ),
                      ),
                    ),
                  ],
                  if (staffMembers.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    Text(l10n.staffSectionTitle, style: textTheme.titleMedium),
                    const SizedBox(height: FactorySpacing.space3),
                    ...staffMembers.map(
                      (staff) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: FactorySpacing.space2,
                        ),
                        child: _StaffOption(
                          staff: staff,
                          selected: _selectedStaffId == staff.id,
                          onTap: () =>
                              setState(() => _selectedStaffId = staff.id),
                        ),
                      ),
                    ),
                  ],
                  if (widget.provider.vertical == 'auto' &&
                      currentUser != null) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    Text(
                      l10n.vehiclesSectionTitle,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    if (vehicles.isEmpty)
                      FactoryEmptyState(
                        icon: Symbols.directions_car_rounded,
                        title: l10n.vehiclesEmptyTitle,
                        message: l10n.vehiclesEmptyMessage,
                      )
                    else
                      ...vehicles.map(
                        (vehicle) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: FactorySpacing.space2,
                          ),
                          child: _VehicleOption(
                            vehicle: vehicle,
                            selected: _selectedVehicleId == vehicle.id,
                            onTap: () =>
                                setState(() => _selectedVehicleId = vehicle.id),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FactoryButton(
                        variant: FactoryButtonVariant.text,
                        icon: Symbols.add_rounded,
                        label: l10n.addVehicleButton,
                        onPressed: () => _addVehicle(currentUser.id),
                      ),
                    ),
                  ],
                  const SizedBox(height: FactorySpacing.space6),
                  Text(l10n.servicesSectionTitle, style: textTheme.titleMedium),
                  const SizedBox(height: FactorySpacing.space2),
                  ...widget.provider.services.map(
                    (service) => FactoryServiceCard(
                      title: service.title,
                      metaText: l10n.serviceDurationMinutes(
                        service.durationMinutes,
                      ),
                      price: service.price,
                      selected: _selectedServiceId == service.id,
                      onTap: () =>
                          setState(() => _selectedServiceId = service.id),
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space6),
                  Text(
                    l10n.availableTimesSectionTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  slotsAsync.when(
                    data: (slots) {
                      final openSlots = slots.where((s) => s.isOpen).toList();
                      if (openSlots.isEmpty) {
                        return FactoryEmptyState(
                          icon: Symbols.event_busy_rounded,
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
                                label: formatMonthDayTime(
                                  l10n,
                                  slot.startsAt.toLocal(),
                                ),
                                state: _selectedSlotId == slot.id
                                    ? FactoryTimeSlotState.selected
                                    : FactoryTimeSlotState.available,
                                onTap: () =>
                                    setState(() => _selectedSlotId = slot.id),
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const FactoryLoadingState(),
                    error: (error, stackTrace) => FactoryErrorState(
                      message: l10n.errorAvailabilityLoadFailed,
                      onRetry: () => ref.invalidate(
                        availabilitySlotsProvider(widget.provider.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _BookingCta(
              selectedService: _selectedService(),
              isLoading: _isBooking,
              onPressed:
                  (_selectedServiceId != null &&
                      _selectedSlotId != null &&
                      (masters.isEmpty || _selectedMasterId != null) &&
                      (mechanics.isEmpty || _selectedMechanicId != null) &&
                      (!requiresVehicleSelection ||
                          _selectedVehicleId != null) &&
                      (cleaners.isEmpty || _selectedCleanerId != null) &&
                      (staffMembers.isEmpty || _selectedStaffId != null) &&
                      !_isBooking)
                  ? _book
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  ServiceSummary? _selectedService() {
    for (final service in widget.provider.services) {
      if (service.id == _selectedServiceId) return service;
    }
    return null;
  }

  Future<void> _addVehicle(String userId) async {
    final result = await showAddVehicleDialog(context);
    if (result == null) return;
    final vehicle = await ref
        .read(autoApiProvider)
        .registerVehicle(
          ownerUserId: userId,
          make: result.make,
          model: result.model,
          year: result.year,
          licensePlate: result.licensePlate,
        );
    ref.invalidate(vehiclesProvider(userId));
    setState(() => _selectedVehicleId = vehicle.id);
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
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final service = widget.provider.services.firstWhere(
      (s) => s.id == _selectedServiceId,
    );
    try {
      // A master/mechanic/cleaner was selected only when this provider has a
      // beauty/auto/cleaning staff directory (see the Book button's enable
      // condition above) — route through the matching vertical booking
      // endpoint so its own rules are enforced server-side; otherwise use
      // Core's plain booking flow, unchanged from before verticals existed.
      final Booking booking;
      if (_selectedMechanicId != null) {
        booking = await ref
            .read(autoApiProvider)
            .createAutoBooking(
              userId: currentUser.id,
              mechanicId: _selectedMechanicId!,
              vehicleId: _selectedVehicleId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: service.price,
            );
      } else if (_selectedMasterId != null) {
        booking = await ref
            .read(beautyApiProvider)
            .createBeautyBooking(
              userId: currentUser.id,
              masterId: _selectedMasterId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: service.price,
            );
      } else if (_selectedCleanerId != null) {
        booking = await ref
            .read(cleaningApiProvider)
            .createCleaningBooking(
              userId: currentUser.id,
              cleanerId: _selectedCleanerId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: service.price,
            );
      } else if (_selectedStaffId != null) {
        booking = await ref
            .read(staffApiProvider)
            .createStaffBooking(
              userId: currentUser.id,
              staffId: _selectedStaffId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: service.price,
            );
      } else {
        booking = await ref
            .read(bookingApiProvider)
            .createBooking(
              userId: currentUser.id,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: service.price,
            );
      }

      // Charged right after booking creation, in the same flow — see
      // SESSION_NOTES.md for why this isn't gated behind a webhook yet
      // (no real payment provider/webhook exists; the mock resolves
      // synchronously, so there's nothing async to wait on).
      String message = l10n.bookingConfirmed;
      try {
        final payment = await ref
            .read(paymentsApiProvider)
            .createPayment(booking.id);
        message = payment.status == 'SUCCEEDED'
            ? l10n.bookingConfirmedAndPaid
            : l10n.bookingConfirmedPaymentStatus(payment.status.toLowerCase());
      } on PaymentException catch (e) {
        message = l10n.bookingConfirmedButError(e.localizedMessage(l10n));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } on BeautyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } on AutoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } on CleaningException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } on StaffException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorBookingGeneric(e.toString()))),
      );
      setState(() => _isBooking = false);
    }
  }
}

/// The sticky bottom booking bar — Customer App Redesign board
/// (2026-09-05): a gradient CTA pinned below the scroll, with the selected
/// service's price alongside it, rather than an inline full-width button at
/// the end of the form. Purely a layout/visual change: the underlying
/// selection state and the multi-vertical `_book()` logic above are
/// untouched — a full step-by-step wizard (as the design board's simpler
/// generic mock-up implies) was deliberately not attempted here. This
/// screen's real flow branches across four separate vertical-specific
/// booking APIs (beauty/auto/cleaning/generic staff) with its own staff/
/// vehicle selection per vertical, none of which the board's mock-up (a
/// single generic service->date->time->confirm flow) accounts for — a
/// previous session explicitly deferred that exact restructuring as too
/// risky for a real-money flow, and that reasoning still holds.
class _BookingCta extends StatelessWidget {
  const _BookingCta({
    required this.selectedService,
    required this.isLoading,
    required this.onPressed,
  });

  final ServiceSummary? selectedService;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        FactorySpacing.space4,
        FactorySpacing.space3,
        FactorySpacing.space4,
        FactorySpacing.space4,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (selectedService != null) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedService!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary),
                  ),
                  FactoryPriceText(
                    amount: selectedService!.price,
                    currencySymbol: selectedService!.currency,
                    fontSize: 16,
                    color: colors.text,
                  ),
                ],
              ),
            ),
            const SizedBox(width: FactorySpacing.space3),
            FactoryButton(
              label: l10n.bookButton,
              variant: FactoryButtonVariant.gradient,
              isLoading: isLoading,
              onPressed: onPressed,
            ),
          ] else
            Expanded(
              child: FactoryButton(
                label: l10n.bookButton,
                variant: FactoryButtonVariant.gradient,
                expand: true,
                isLoading: isLoading,
                onPressed: onPressed,
              ),
            ),
        ],
      ),
    );
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

    return FactorySelectableTile(
      title: master.displayName,
      subtitle: master.bio != null
          ? Text(
              master.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      leading: FactoryAvatar(
        initials: initialsFor(master.displayName),
        image: master.photoUrl != null ? NetworkImage(master.photoUrl!) : null,
      ),
      trailing: IconButton(
        icon: const Icon(Symbols.photo_library_rounded),
        tooltip: l10n.viewPortfolioTooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          foregroundColor: colors.textSecondary,
        ),
        onPressed: onViewPortfolio,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _MechanicOption extends StatelessWidget {
  const _MechanicOption({
    required this.mechanic,
    required this.selected,
    required this.onTap,
  });

  final Mechanic mechanic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      title: mechanic.displayName,
      subtitle: mechanic.bio != null
          ? Text(
              mechanic.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      leading: FactoryAvatar(
        initials: initialsFor(mechanic.displayName),
        image: mechanic.photoUrl != null
            ? NetworkImage(mechanic.photoUrl!)
            : null,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _CleanerOption extends StatelessWidget {
  const _CleanerOption({
    required this.cleaner,
    required this.selected,
    required this.onTap,
  });

  final Cleaner cleaner;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      title: cleaner.displayName,
      subtitle: cleaner.bio != null
          ? Text(
              cleaner.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      leading: FactoryAvatar(
        initials: initialsFor(cleaner.displayName),
        image: cleaner.photoUrl != null
            ? NetworkImage(cleaner.photoUrl!)
            : null,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _StaffOption extends StatelessWidget {
  const _StaffOption({
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  final Staff staff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      title: staff.displayName,
      subtitle: staff.bio != null
          ? Text(
              staff.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      leading: FactoryAvatar(
        initials: initialsFor(staff.displayName),
        image: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;

    return FactorySelectableTile(
      title: vehicle.displayName,
      subtitle: Text(
        vehicle.licensePlate,
        style: FactoryTypography.mono(size: 13, color: colors.textTertiary),
      ),
      leading: Icon(
        Symbols.directions_car_rounded,
        color: colors.textSecondary,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

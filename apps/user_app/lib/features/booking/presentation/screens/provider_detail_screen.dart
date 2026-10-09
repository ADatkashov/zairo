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
import '../../../auto/data/auto_exception.dart';
import '../../../auto/data/models/mechanic.dart';
import '../../../auto/data/models/vehicle.dart';
import '../../../auto/presentation/providers/auto_providers.dart';
import '../../../auto/presentation/widgets/add_vehicle_dialog.dart';
import '../../../beauty/data/beauty_exception.dart';
import '../../../beauty/data/models/master.dart';
import '../../../beauty/presentation/providers/beauty_providers.dart';
import '../../../cleaning/data/cleaning_exception.dart';
import '../../../cleaning/data/models/cleaner.dart';
import '../../../cleaning/presentation/providers/cleaning_providers.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/data/models/service_summary.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../payments/data/payment_exception.dart';
import '../../../payments/data/models/payment.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../staff/data/models/staff.dart';
import '../../../staff/data/staff_exception.dart';
import '../../../staff/presentation/providers/staff_providers.dart';
import '../../../workforce/data/models/any_slot.dart';
import '../../../workforce/presentation/providers/workforce_providers.dart';
import '../../data/booking_exception.dart';
import '../../data/models/availability_slot.dart';
import '../../data/models/booking.dart';
import '../../data/models/payment_plan.dart';
import '../providers/booking_providers.dart';
import '../widgets/day_slot_picker.dart';
import 'booking_confirmation_screen.dart';
import 'booking_payment_screen.dart';

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

  /// "Any master": the customer picks a time, the system assigns a free person.
  bool _anyMaster = false;

  /// The selected service's price for the selected person (see build).
  double? _effectivePrice;

  /// Whether the current selection is booked as "any master" — set during build, read by [_book].
  bool _anyModeNow = false;

  /// Start time of the picked slot, captured when it is picked (the slot lists differ per mode).
  DateTime? _selectedSlotStartsAt;
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
    // The business's own rules about workers: whether customers may pick a person, or only "any master".
    final allowChoice =
        ref.watch(allowsWorkerChoiceProvider(widget.provider.id)).value ?? true;
    final hasWorkers = masters.isNotEmpty ||
        mechanics.isNotEmpty ||
        cleaners.isNotEmpty ||
        staffMembers.isNotEmpty;
    final anyMode = hasWorkers && (_anyMaster || !allowChoice);
    _anyModeNow = anyMode;
    final selectedWorkerId = _selectedMasterId ??
        _selectedMechanicId ??
        _selectedCleanerId ??
        _selectedStaffId;
    // A person may charge their own price (the owner's choice); it is shown here, before the customer confirms,
    // exactly as the server will charge it. "Any master" is always the base price.
    final serviceForPrice = _selectedService();
    final workerPrices = serviceForPrice == null
        ? const <String, double>{}
        : ref.watch(serviceWorkerPricesProvider((widget.provider.id, serviceForPrice.id))).value ??
              const <String, double>{};
    _effectivePrice = serviceForPrice == null
        ? null
        : (selectedWorkerId == null || anyMode ? serviceForPrice.price : workerPrices[selectedWorkerId]) ??
              serviceForPrice.price;

    // Back is blocked while the booking request is in flight so a swipe
    // can't leave the user guessing whether it went through.
    final scaffold = Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: widget.provider.name,
        actions: [
          IconButton(
            icon: const Icon(Symbols.chat_rounded),
            tooltip: l10n.messageProviderTooltip,
            onPressed: () => _openMessageThread(currentUser),
          ),
          FavoriteButton(providerId: widget.provider.id),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  _ProviderHero(provider: widget.provider),
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
                        onPressed: () => context.push(
                          AppRoutes.map(
                            providerName: widget.provider.name,
                            latitude: widget.provider.latitude!,
                            longitude: widget.provider.longitude!,
                            distanceKm: widget.provider.distanceKm,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: FactorySpacing.space3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FactoryButton(
                      variant: FactoryButtonVariant.secondary,
                      icon: Symbols.workspace_premium_rounded,
                      label: l10n.loyaltyEntryTileTitle,
                      onPressed: () => context.push(
                        AppRoutes.loyalty(
                          widget.provider.id,
                          providerName: widget.provider.name,
                        ),
                      ),
                    ),
                  ),
                  if (hasWorkers && allowChoice) ...[
                    const SizedBox(height: FactorySpacing.space6),
                    _AnyMasterOption(
                      selected: _anyMaster,
                      onTap: () => setState(() {
                        _anyMaster = true;
                        _selectedMasterId = null;
                        _selectedMechanicId = null;
                        _selectedCleanerId = null;
                        _selectedStaffId = null;
                        _selectedSlotId = null;
                        _selectedSlotStartsAt = null;
                      }),
                    ),
                  ],
                  if (masters.isNotEmpty && allowChoice) ...[
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
                          onTap: () => _pickWorker(
                            () => _selectedMasterId = master.id,
                          ),
                          onViewPortfolio: () => context.push(
                            AppRoutes.portfolio(
                              master.id,
                              masterName: master.displayName,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (mechanics.isNotEmpty && allowChoice) ...[
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
                          onTap: () => _pickWorker(
                            () => _selectedMechanicId = mechanic.id,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (cleaners.isNotEmpty && allowChoice) ...[
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
                          onTap: () => _pickWorker(
                            () => _selectedCleanerId = cleaner.id,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (staffMembers.isNotEmpty && allowChoice) ...[
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
                          onTap: () => _pickWorker(
                            () => _selectedStaffId = staff.id,
                          ),
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
                        compact: true,
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
                      onTap: () => setState(() {
                        if (_selectedServiceId != service.id && anyMode) {
                          _selectedSlotId = null;
                          _selectedSlotStartsAt = null;
                        }
                        _selectedServiceId = service.id;
                      }),
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space6),
                  Text(
                    l10n.availableTimesSectionTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  _buildTimes(
                    l10n,
                    providerSlots: slotsAsync,
                    hasWorkers: hasWorkers,
                    anyMode: anyMode,
                    workerId: selectedWorkerId,
                  ),
                ],
              ),
            ),
            _BookingCta(
              selectedService: _selectedService(),
              price: _effectivePrice,
              plan: _paymentPlan(),
              isLoading: _isBooking,
              onPressed:
                  (_selectedServiceId != null &&
                      _selectedSlotId != null &&
                      (anyMode ||
                          ((masters.isEmpty || _selectedMasterId != null) &&
                              (mechanics.isEmpty ||
                                  _selectedMechanicId != null) &&
                              (cleaners.isEmpty ||
                                  _selectedCleanerId != null) &&
                              (staffMembers.isEmpty ||
                                  _selectedStaffId != null))) &&
                      (!requiresVehicleSelection ||
                          _selectedVehicleId != null) &&
                      !_isBooking)
                  ? _book
                  : null,
            ),
          ],
        ),
      ),
    );
    return PopScope(canPop: !_isBooking, child: scaffold);
  }

  Future<Booking> _withPaymentAmounts(Booking created) async {
    if (created.depositAmount != null) return created;
    try {
      return await ref.read(bookingApiProvider).getBooking(created.id);
    } catch (_) {
      return created;
    }
  }

  /// Null while the deposit policy is loading or unreadable — the CTA then
  /// falls back to the plain price rather than claiming "free" on a guess.
  PaymentPlan? _paymentPlan() {
    final service = _selectedService();
    final policy = ref.watch(depositPolicyProvider(widget.provider.id)).value;
    if (service == null || policy == null) return null;
    return PaymentPlan.fromPolicy(policy, _effectivePrice ?? service.price);
  }

  ServiceSummary? _selectedService() {
    for (final service in widget.provider.services) {
      if (service.id == _selectedServiceId) return service;
    }
    return null;
  }

  /// Same in-flow login gate as [FavoriteButton]: logged out just opens
  /// LoginScreen instead of silently failing or disabling the action.
  void _openMessageThread(UserSummary? currentUser) {
    if (currentUser == null) {
      pushAuthScreen(context, const LoginScreen());
      return;
    }
    context.push(
      AppRoutes.chat(widget.provider.id, providerName: widget.provider.name),
    );
  }

  /// Picking a person (rather than "any master") shows that person's own times, so the previous pick is dropped.
  void _pickWorker(VoidCallback select) {
    setState(() {
      _anyMaster = false;
      _selectedMasterId = null;
      _selectedMechanicId = null;
      _selectedCleanerId = null;
      _selectedStaffId = null;
      select();
      _selectedSlotId = null;
      _selectedSlotStartsAt = null;
    });
  }

  void _onSlotPicked(String slotId, List<AvailabilitySlot> slots) {
    DateTime? startsAt;
    for (final slot in slots) {
      if (slot.id == slotId) {
        startsAt = slot.startsAt;
        break;
      }
    }
    setState(() {
      _selectedSlotId = slotId;
      _selectedSlotStartsAt = startsAt;
    });
  }

  void _invalidateTimes() {
    ref.invalidate(availabilitySlotsProvider(widget.provider.id));
    ref.invalidate(workerSlotsProvider);
    ref.invalidate(anySlotsProvider);
  }

  /// The times a customer may pick: "any master" merges everyone who does the service, a chosen person shows only
  /// their own bookable times, and a business without workers keeps the plain provider-level list.
  Widget _buildTimes(
    AppLocalizations l10n, {
    required AsyncValue<List<AvailabilitySlot>> providerSlots,
    required bool hasWorkers,
    required bool anyMode,
    required String? workerId,
  }) {
    Widget picker(List<AvailabilitySlot> slots) {
      final openSlots = slots.where((s) => s.isOpen).toList();
      if (openSlots.isEmpty) {
        return FactoryEmptyState(
          compact: true,
          icon: Symbols.event_busy_rounded,
          title: l10n.noOpenTimesTitle,
          message: l10n.noOpenTimesMessage,
        );
      }
      return DaySlotPicker(
        slots: openSlots,
        selectedSlotId: _selectedSlotId,
        onSelected: (id) => _onSlotPicked(id, openSlots),
      );
    }

    Widget hint(String title, String message) => FactoryEmptyState(
      compact: true,
      icon: Symbols.schedule_rounded,
      title: title,
      message: message,
    );

    Widget errorView() => FactoryErrorState(
      message: l10n.errorAvailabilityLoadFailed,
      onRetry: _invalidateTimes,
    );

    // Business with no people to choose from: the plain provider-level list, as before.
    AsyncValue<List<AvailabilitySlot>> legacy() => providerSlots;
    Widget legacyView() => legacy().when(
      data: picker,
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => errorView(),
    );

    if (!hasWorkers) return legacyView();

    if (anyMode) {
      final serviceId = _selectedServiceId;
      if (serviceId == null) {
        return hint(l10n.workforceChooseServiceTitle, l10n.workforceChooseServiceMessage);
      }
      return ref.watch(anySlotsProvider((widget.provider.id, serviceId))).when(
        data: (slots) => picker([
          for (final AnySlot a in slots)
            AvailabilitySlot(
              id: a.slotId,
              providerId: widget.provider.id,
              startsAt: a.startsAt,
              endsAt: a.endsAt,
              status: 'OPEN',
            ),
        ]),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => errorView(),
      );
    }

    if (workerId == null) {
      return hint(l10n.workforceChooseMasterTitle, l10n.workforceChooseMasterMessage);
    }
    return ref.watch(workerSlotsProvider((widget.provider.id, workerId))).when(
      data: picker,
      loading: () => const FactoryLoadingState(),
      // An older server without the per-person endpoint: fall back to the business's list.
      error: (error, stackTrace) => legacyView(),
    );
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
      await pushAuthScreen(context, const LoginScreen());
      return;
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final service = widget.provider.services.firstWhere(
      (s) => s.id == _selectedServiceId,
    );
    // Captured before the booking call below, since a successful booking
    // consumes the slot and the next read of this provider would no longer
    // contain it — needed only to show the "when" on BookingConfirmationScreen.
    DateTime? slotStartsAt = _selectedSlotStartsAt;
    if (slotStartsAt == null) {
      for (final slot
          in ref.read(availabilitySlotsProvider(widget.provider.id)).value ??
              const <AvailabilitySlot>[]) {
        if (slot.id == _selectedSlotId) {
          slotStartsAt = slot.startsAt;
          break;
        }
      }
    }
    try {
      // A master/mechanic/cleaner was selected only when this provider has a
      // beauty/auto/cleaning staff directory (see the Book button's enable
      // condition above) — route through the matching vertical booking
      // endpoint so its own rules are enforced server-side; otherwise use
      // Core's plain booking flow, unchanged from before verticals existed.
      Booking booking;
      if (_anyModeNow && slotStartsAt != null) {
        // "Any master": the system assigns a free person for the picked time.
        booking = await ref
            .read(workforceApiProvider)
            .bookAny(
              providerId: widget.provider.id,
              userId: currentUser.id,
              serviceId: service.id,
              startsAt: slotStartsAt,
              vehicleId: _selectedVehicleId,
            );
      } else if (_selectedMechanicId != null) {
        booking = await ref
            .read(autoApiProvider)
            .createAutoBooking(
              userId: currentUser.id,
              mechanicId: _selectedMechanicId!,
              vehicleId: _selectedVehicleId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: _effectivePrice ?? service.price,
            );
      } else if (_selectedMasterId != null) {
        booking = await ref
            .read(beautyApiProvider)
            .createBeautyBooking(
              userId: currentUser.id,
              masterId: _selectedMasterId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: _effectivePrice ?? service.price,
            );
      } else if (_selectedCleanerId != null) {
        booking = await ref
            .read(cleaningApiProvider)
            .createCleaningBooking(
              userId: currentUser.id,
              cleanerId: _selectedCleanerId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: _effectivePrice ?? service.price,
            );
      } else if (_selectedStaffId != null) {
        booking = await ref
            .read(staffApiProvider)
            .createStaffBooking(
              userId: currentUser.id,
              staffId: _selectedStaffId!,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: _effectivePrice ?? service.price,
            );
      } else {
        booking = await ref
            .read(bookingApiProvider)
            .createBooking(
              userId: currentUser.id,
              serviceId: service.id,
              availabilitySlotId: _selectedSlotId!,
              totalPrice: _effectivePrice ?? service.price,
            );
      }

      // The beauty/auto/cleaning/staff endpoints return a slimmer body with no
      // deposit figures, so re-read the booking from the generic endpoint —
      // otherwise the confirmation can't tell a deposit from "pay at venue".
      booking = await _withPaymentAmounts(booking);

      // Charged right after booking creation, in the same flow. The mock
      // provider resolves synchronously (SUCCEEDED); a redirect-based one
      // (Freedom Pay) answers PENDING with a checkout page, and the booking
      // is only confirmed once its webhook arrives — see BookingPaymentScreen.
      //
      // A booking with nothing due online (the business takes no advance
      // payment, or the service is free) arrives already CONFIRMED — the
      // customer pays at the venue — so there is no payment to start.
      String? paymentErrorMessage;
      Payment? payment;
      var choosePayment = false;
      try {
        if (booking.status == 'PENDING_PAYMENT') {
          // With saved cards the customer picks how to pay on the payment screen, so no payment yet.
          final hasCards = (await usableSavedCards(ref.read(paymentsApiProvider))).isNotEmpty;
          if (!hasCards) {
            payment = await ref.read(paymentsApiProvider).createPayment(booking.id);
          } else {
            choosePayment = true;
          }
        }
      } on PaymentException catch (e) {
        paymentErrorMessage = l10n.bookingConfirmedButError(
          e.localizedMessage(l10n),
        );
      }

      if (!mounted) return;
      final confirmation = BookingConfirmationArgs(
        booking: booking,
        providerId: widget.provider.id,
        providerName: widget.provider.name,
        providerVertical: widget.provider.vertical,
        service: service,
        slotStartsAt: slotStartsAt,
        latitude: widget.provider.latitude,
        longitude: widget.provider.longitude,
      );
      if (choosePayment) {
        context.pushReplacement(
          AppRoutes.bookingPayment,
          extra: BookingPaymentArgs(booking: booking, confirmation: confirmation),
        );
        return;
      }
      if (payment != null && payment.status != 'SUCCEEDED') {
        // Not paid yet: the customer must pay (or retry) before this is a confirmed booking.
        context.pushReplacement(
          AppRoutes.bookingPayment,
          extra: BookingPaymentArgs(
            booking: booking,
            confirmation: confirmation,
            payment: payment,
          ),
        );
        return;
      }
      if (paymentErrorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(paymentErrorMessage)));
      }
      // Board 19 (v2 design audit) — a durable confirmation screen, not a
      // snackbar that's gone in a few seconds, so replaces this route
      // rather than pushing on top of it.
      context.pushReplacement(
        AppRoutes.bookingConfirmation,
        extra: confirmation,
      );
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      _invalidateTimes();
      setState(() {
        _selectedSlotId = null;
        _selectedSlotStartsAt = null;
        _isBooking = false;
      });
    } on BeautyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      _invalidateTimes();
      setState(() {
        _selectedSlotId = null;
        _selectedSlotStartsAt = null;
        _isBooking = false;
      });
    } on AutoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      _invalidateTimes();
      setState(() {
        _selectedSlotId = null;
        _selectedSlotStartsAt = null;
        _isBooking = false;
      });
    } on CleaningException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      _invalidateTimes();
      setState(() {
        _selectedSlotId = null;
        _selectedSlotStartsAt = null;
        _isBooking = false;
      });
    } on StaffException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.localizedMessage(l10n))));
      _invalidateTimes();
      setState(() {
        _selectedSlotId = null;
        _selectedSlotStartsAt = null;
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
    required this.price,
    required this.plan,
    required this.isLoading,
    required this.onPressed,
  });

  final ServiceSummary? selectedService;
  final double? price;
  final PaymentPlan? plan;
  final bool isLoading;
  final VoidCallback? onPressed;

  /// What the customer is charged *now* leads; the full service price only
  /// leads when no deposit policy is known.
  List<Widget> _paymentLines(BuildContext context, AppLocalizations l10n, FactoryColors colors) {
    final service = selectedService!;
    final textTheme = Theme.of(context).textTheme;
    final p = plan;
    if (p == null) {
      return [
        FactoryPriceText(
          amount: price ?? service.price,
          currencySymbol: service.currency,
          fontSize: 16,
          color: colors.text,
        ),
      ];
    }
    final suffixStyle = textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          FactoryPriceText(
            amount: p.dueNow,
            currencySymbol: service.currency,
            fontSize: 18,
            weight: FontWeight.w800,
            color: colors.text,
          ),
          const SizedBox(width: FactorySpacing.space1),
          Text(
            p.mode == PaymentMode.full ? l10n.bookingCtaFullPayment : l10n.bookingCtaDueNow,
            style: suffixStyle,
          ),
        ],
      ),
      if (p.mode != PaymentMode.full)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.bookingPayAtVenue}: ', style: suffixStyle),
            FactoryPriceText(
              amount: p.atVenue,
              currencySymbol: service.currency,
              fontSize: 12,
              weight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ],
        ),
    ];
  }

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
        color: colors.surface,
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
                  ..._paymentLines(context, l10n, colors),
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

class _AnyMasterOption extends StatelessWidget {
  const _AnyMasterOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return FactorySelectableTile(
      title: l10n.anyMasterOptionTitle,
      subtitle: Text(
        l10n.anyMasterOptionSubtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      ),
      leading: Icon(Symbols.groups_rounded, color: colors.textSecondary),
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


/// Photo-first header: the business's cover photo under a soft scrim, with
/// the vertical's icon on a tinted gradient while there is no photo (or it
/// fails to load). Radius follows the app profile.
class _ProviderHero extends StatelessWidget {
  const _ProviderHero({required this.provider});

  final ProviderSearchResult provider;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final radius =
        context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryTint, colors.surfaceAlt],
        ),
      ),
      child: Center(
        child: Icon(
          switch (provider.vertical) {
            'auto' => Symbols.directions_car_filled_rounded,
            'cleaning' => Symbols.cleaning_services_rounded,
            _ => Symbols.content_cut_rounded,
          },
          size: 56,
          color: colors.primaryStrong.withValues(alpha: 0.5),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (provider.coverPhotoUrl == null)
              fallback
            else
              Image.network(
                provider.coverPhotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            if (provider.coverPhotoUrl != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x33000000)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

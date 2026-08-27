import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auto/data/models/admin_mechanic.dart';
import '../../../auto/presentation/providers/auto_admin_providers.dart';
import '../../../auto/presentation/widgets/add_mechanic_dialog.dart';
import '../../../auto/presentation/widgets/manage_mechanic_services_dialog.dart';
import '../../../beauty/data/models/admin_master.dart';
import '../../../beauty/presentation/providers/beauty_admin_providers.dart';
import '../../../beauty/presentation/widgets/add_master_dialog.dart';
import '../../../beauty/presentation/widgets/add_portfolio_item_dialog.dart';
import '../../../beauty/presentation/widgets/manage_master_services_dialog.dart';
import '../../data/models/admin_booking.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/admin_service.dart';
import '../providers/salon_providers.dart';
import '../widgets/add_service_dialog.dart';
import '../widgets/add_slot_dialog.dart';
import '../widgets/recurring_schedule_dialog.dart';

class SalonDetailScreen extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const SalonDetailScreen({super.key, required this.provider});

  @override
  ConsumerState<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends ConsumerState<SalonDetailScreen> {
  late AdminProvider _provider = widget.provider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(
        title: _provider.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editBusinessTooltip,
            onPressed: () async {
              final updated = await showDialog<AdminProvider>(
                context: context,
                builder: (_) => _EditSalonDialog(provider: _provider),
              );
              if (updated != null) {
                setState(() => _provider = updated);
                ref.invalidate(myProvidersProvider(_provider.ownerUserId));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FactoryBadge(label: _capitalize(_provider.vertical)),
              FactoryBadge(
                label: _providerStatusLabel(l10n, _provider.status),
                variant: _providerStatusVariant(_provider.status),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space6),
          _DashboardMetricsSection(providerId: _provider.id),
          const SizedBox(height: FactorySpacing.space6),
          _ServicesSection(providerId: _provider.id),
          const SizedBox(height: FactorySpacing.space6),
          _AvailabilitySection(providerId: _provider.id),
          if (_provider.vertical == 'beauty') ...[
            const SizedBox(height: FactorySpacing.space6),
            _MastersSection(providerId: _provider.id),
          ],
          if (_provider.vertical == 'auto') ...[
            const SizedBox(height: FactorySpacing.space6),
            _MechanicsSection(providerId: _provider.id),
          ],
          const SizedBox(height: FactorySpacing.space6),
          _BookingsSection(providerId: _provider.id),
        ],
      ),
    );
  }
}

FactoryBadgeVariant _providerStatusVariant(String status) => switch (status) {
      'ACTIVE' => FactoryBadgeVariant.available,
      'PENDING' => FactoryBadgeVariant.limited,
      'SUSPENDED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

String _providerStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'ACTIVE' => l10n.providerStatusActive,
      'PENDING' => l10n.providerStatusPending,
      'SUSPENDED' => l10n.providerStatusSuspended,
      _ => _capitalize(status),
    };

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

/// Owner-editable fields only — vertical and status aren't here on purpose,
/// see backend's Provider.update() for why.
class _EditSalonDialog extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const _EditSalonDialog({required this.provider});

  @override
  ConsumerState<_EditSalonDialog> createState() => _EditSalonDialogState();
}

class _EditSalonDialogState extends ConsumerState<_EditSalonDialog> {
  late final _nameController = TextEditingController(text: widget.provider.name);
  late final _latController = TextEditingController(text: widget.provider.latitude?.toString() ?? '');
  late final _lngController = TextEditingController(text: widget.provider.longitude?.toString() ?? '');
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.editBusinessTooltip,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactoryTextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            label: l10n.businessNameLabel,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _latController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            label: l10n.latitudeOptionalLabel,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _lngController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            label: l10n.longitudeOptionalLabel,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.saveButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.validationBusinessNameRequired);
      return;
    }
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    final lat = latText.isEmpty ? null : double.tryParse(latText);
    final lng = lngText.isEmpty ? null : double.tryParse(lngText);
    if ((latText.isNotEmpty && lat == null) || (lngText.isNotEmpty && lng == null)) {
      setState(() => _error = l10n.validationLatLngInvalid);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final updated = await ref.read(salonAdminApiProvider).updateProvider(
            providerId: widget.provider.id,
            name: name,
            latitude: lat,
            longitude: lng,
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() {
        _error = l10n.errorSaveBusinessFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

class _DashboardMetricsSection extends ConsumerWidget {
  final String providerId;

  const _DashboardMetricsSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final metricsAsync = ref.watch(providerDashboardMetricsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.dashboardMetricsSectionTitle),
        metricsAsync.when(
          data: (metrics) {
            if (metrics.totalBookings == 0) {
              return Text(
                l10n.dashboardNoDataYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: FactorySpacing.space3,
                  runSpacing: FactorySpacing.space3,
                  children: [
                    _StatTile(
                      label: l10n.dashboardTotalRevenueLabel,
                      value: FactoryPriceText(amount: metrics.totalRevenue, fontSize: 18),
                    ),
                    _StatTile(label: l10n.dashboardTotalBookingsLabel, value: Text('${metrics.totalBookings}')),
                    _StatTile(label: l10n.dashboardCompletedBookingsLabel, value: Text('${metrics.completedBookings}')),
                    _StatTile(label: l10n.dashboardCancelledBookingsLabel, value: Text('${metrics.cancelledBookings}')),
                    _StatTile(
                      label: l10n.dashboardCancellationRateLabel,
                      value: Text('${(metrics.cancellationRate * 100).round()}%'),
                    ),
                    _StatTile(label: l10n.dashboardTotalCustomersLabel, value: Text('${metrics.totalCustomers}')),
                    if (metrics.averageCheck != null)
                      _StatTile(
                        label: l10n.dashboardAverageCheckLabel,
                        value: FactoryPriceText(amount: metrics.averageCheck!, fontSize: 18),
                      ),
                  ],
                ),
                if (metrics.topServices.isNotEmpty) ...[
                  const SizedBox(height: FactorySpacing.space4),
                  Text(l10n.dashboardTopServicesTitle, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: FactorySpacing.space2),
                  ...metrics.topServices.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(s.title ?? '—')),
                          Text('${s.bookingCount}', style: TextStyle(color: colors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorDashboardLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final Widget value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return FactoryCard(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 4),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              child: value,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  final String providerId;

  const _ServicesSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final showInactive = ref.watch(showInactiveServicesProvider(providerId));
    final servicesAsync = ref.watch(providerServicesProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(providerServicesProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.servicesSectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                label: showInactive ? l10n.hideRemovedButton : l10n.showRemovedButton,
                variant: FactoryButtonVariant.text,
                onPressed: () =>
                    ref.read(showInactiveServicesProvider(providerId).notifier).state = !showInactive,
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddServiceDialog(providerId: providerId),
                  );
                  if (added == true) refresh();
                },
              ),
            ],
          ),
        ),
        servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return Text(
                showInactive ? l10n.noServicesYet : l10n.noActiveServices,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: services
                  .map((s) => _ServiceAdminRow(
                        service: s,
                        onEdit: () async {
                          final saved = await showDialog<bool>(
                            context: context,
                            builder: (_) => AddServiceDialog(providerId: providerId, existing: s),
                          );
                          if (saved == true) refresh();
                        },
                        onRemove: () async {
                          await ref.read(salonAdminApiProvider).deactivateService(s.id);
                          refresh();
                        },
                        onReactivate: () async {
                          await ref.read(salonAdminApiProvider).reactivateService(s.id);
                          refresh();
                        },
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorServicesLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _ServiceAdminRow extends StatelessWidget {
  const _ServiceAdminRow({
    required this.service,
    required this.onEdit,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminService service;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        service.title,
                        style: textTheme.titleSmall?.copyWith(color: service.active ? colors.text : colors.textTertiary),
                      ),
                    ),
                    if (!service.active) ...[
                      const SizedBox(width: FactorySpacing.space2),
                      FactoryBadge(label: l10n.removedBadge),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(l10n.serviceDurationMinutes(service.durationMinutes),
                    style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          FactoryPriceText(amount: service.price, fontSize: 14, color: service.active ? null : colors.textTertiary),
          const SizedBox(width: FactorySpacing.space2),
          if (service.active)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l10n.editTooltip, onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.removeTooltip, onPressed: onRemove),
              ],
            )
          else
            FactoryButton(label: l10n.reactivateButton, variant: FactoryButtonVariant.text, onPressed: onReactivate),
        ],
      ),
    );
  }
}

class _AvailabilitySection extends ConsumerWidget {
  final String providerId;

  const _AvailabilitySection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final slotsAsync = ref.watch(providerSlotsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.availabilitySectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                icon: Icons.event_repeat,
                label: l10n.recurringScheduleButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final generated = await showDialog<bool>(
                    context: context,
                    builder: (_) => RecurringScheduleDialog(providerId: providerId),
                  );
                  if (generated == true) ref.invalidate(providerSlotsProvider(providerId));
                },
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddSlotDialog(providerId: providerId),
                  );
                  if (added == true) ref.invalidate(providerSlotsProvider(providerId));
                },
              ),
            ],
          ),
        ),
        slotsAsync.when(
          data: (slots) {
            if (slots.isEmpty) {
              return Text(
                l10n.noSlotsYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              // Only an OPEN slot can be removed (see backend's
              // AvailabilitySlotController.delete()) — a booked one keeps
              // its chip but with no delete affordance.
              children: slots
                  .map((s) => Chip(
                        label: Text(
                          s.status == 'OPEN'
                              ? formatMonthDayTime(l10n, s.startsAt.toLocal())
                              : '${formatMonthDayTime(l10n, s.startsAt.toLocal())} · ${_capitalize(s.status)}',
                        ),
                        onDeleted: s.status == 'OPEN'
                            ? () async {
                                await ref.read(salonAdminApiProvider).deleteSlot(s.id);
                                ref.invalidate(providerSlotsProvider(providerId));
                              }
                            : null,
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorAvailabilityLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _MastersSection extends ConsumerWidget {
  final String providerId;

  const _MastersSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final showInactive = ref.watch(showInactiveMastersProvider(providerId));
    final mastersAsync = ref.watch(adminMastersProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(adminMastersProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.mastersSectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                label: showInactive ? l10n.hideRemovedButton : l10n.showRemovedButton,
                variant: FactoryButtonVariant.text,
                onPressed: () =>
                    ref.read(showInactiveMastersProvider(providerId).notifier).state = !showInactive,
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddMasterDialog(providerId: providerId),
                  );
                  if (added == true) refresh();
                },
              ),
            ],
          ),
        ),
        mastersAsync.when(
          data: (masters) {
            if (masters.isEmpty) {
              return Text(
                showInactive ? l10n.noMastersYet : l10n.noActiveMasters,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: masters
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _MasterAdminRow(
                          master: m,
                          onManageServices: () => showDialog(
                            context: context,
                            builder: (_) => ManageMasterServicesDialog(providerId: providerId, masterId: m.id),
                          ),
                          onAddPortfolioItem: () => showDialog<bool>(
                            context: context,
                            builder: (_) => AddPortfolioItemDialog(masterId: m.id),
                          ),
                          onRemove: () async {
                            await ref.read(beautyAdminApiProvider).deactivateMaster(m.id);
                            refresh();
                          },
                          onReactivate: () async {
                            await ref.read(beautyAdminApiProvider).reactivateMaster(m.id);
                            refresh();
                          },
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorMastersLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _MasterAdminRow extends StatelessWidget {
  const _MasterAdminRow({
    required this.master,
    required this.onManageServices,
    required this.onAddPortfolioItem,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminMaster master;
  final VoidCallback onManageServices;
  final VoidCallback onAddPortfolioItem;
  final VoidCallback onRemove;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: _initialsFor(master.displayName),
        image: master.photoUrl != null ? NetworkImage(master.photoUrl!) : null,
      ),
      title: master.displayName,
      titleColor: master.active ? null : colors.textTertiary,
      subtitle: master.bio != null
          ? Text(
              master.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      trailing: master.active
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.design_services_outlined),
                  tooltip: l10n.manageServicesTooltip,
                  onPressed: onManageServices,
                ),
                IconButton(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  tooltip: l10n.addPortfolioPhotoTooltip,
                  onPressed: onAddPortfolioItem,
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.removeMasterTooltip,
                  onPressed: onRemove,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryBadge(label: l10n.removedBadge),
                const SizedBox(width: FactorySpacing.space2),
                FactoryButton(label: l10n.reactivateButton, variant: FactoryButtonVariant.text, onPressed: onReactivate),
              ],
            ),
    );
  }
}

class _MechanicsSection extends ConsumerWidget {
  final String providerId;

  const _MechanicsSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final showInactive = ref.watch(showInactiveMechanicsProvider(providerId));
    final mechanicsAsync = ref.watch(adminMechanicsProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(adminMechanicsProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.mechanicsSectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                label: showInactive ? l10n.hideRemovedButton : l10n.showRemovedButton,
                variant: FactoryButtonVariant.text,
                onPressed: () =>
                    ref.read(showInactiveMechanicsProvider(providerId).notifier).state = !showInactive,
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddMechanicDialog(providerId: providerId),
                  );
                  if (added == true) refresh();
                },
              ),
            ],
          ),
        ),
        mechanicsAsync.when(
          data: (mechanics) {
            if (mechanics.isEmpty) {
              return Text(
                showInactive ? l10n.noMechanicsYet : l10n.noActiveMechanics,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: mechanics
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _MechanicAdminRow(
                          mechanic: m,
                          onManageServices: () => showDialog(
                            context: context,
                            builder: (_) => ManageMechanicServicesDialog(providerId: providerId, mechanicId: m.id),
                          ),
                          onRemove: () async {
                            await ref.read(autoAdminApiProvider).deactivateMechanic(m.id);
                            refresh();
                          },
                          onReactivate: () async {
                            await ref.read(autoAdminApiProvider).reactivateMechanic(m.id);
                            refresh();
                          },
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorMechanicsLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _MechanicAdminRow extends StatelessWidget {
  const _MechanicAdminRow({
    required this.mechanic,
    required this.onManageServices,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminMechanic mechanic;
  final VoidCallback onManageServices;
  final VoidCallback onRemove;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: _initialsFor(mechanic.displayName),
        image: mechanic.photoUrl != null ? NetworkImage(mechanic.photoUrl!) : null,
      ),
      title: mechanic.displayName,
      titleColor: mechanic.active ? null : colors.textTertiary,
      subtitle: mechanic.bio != null
          ? Text(
              mechanic.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      trailing: mechanic.active
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.design_services_outlined),
                  tooltip: l10n.manageMechanicServicesTooltip,
                  onPressed: onManageServices,
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.removeMechanicTooltip,
                  onPressed: onRemove,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryBadge(label: l10n.removedBadge),
                const SizedBox(width: FactorySpacing.space2),
                FactoryButton(label: l10n.reactivateButton, variant: FactoryButtonVariant.text, onPressed: onReactivate),
              ],
            ),
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  final String providerId;

  const _BookingsSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final bookingsAsync = ref.watch(providerBookingsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.bookingsSectionTitle),
        const SizedBox(height: FactorySpacing.space2),
        bookingsAsync.when(
          data: (bookings) {
            if (bookings.isEmpty) {
              return Text(
                l10n.noBookingsYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: bookings
                  .map((b) => _BookingAdminRow(
                        booking: b,
                        onMarkComplete: b.status == 'CONFIRMED'
                            ? () async {
                                await ref.read(salonAdminApiProvider).completeBooking(b.id);
                                ref.invalidate(providerBookingsProvider(providerId));
                              }
                            : null,
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorBookingsLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _BookingAdminRow extends StatelessWidget {
  const _BookingAdminRow({required this.booking, required this.onMarkComplete});

  final AdminBooking booking;
  final VoidCallback? onMarkComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FactoryPriceText(amount: booking.totalPrice, fontSize: 14),
                    FactoryBadge(
                      label: _bookingStatusLabel(l10n, booking.status),
                      variant: _bookingStatusVariant(booking.status),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatMonthDayTime(l10n, booking.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          if (onMarkComplete != null)
            FactoryButton(label: l10n.markCompleteButton, variant: FactoryButtonVariant.text, onPressed: onMarkComplete),
        ],
      ),
    );
  }
}

FactoryBadgeVariant _bookingStatusVariant(String status) => switch (status) {
      'CONFIRMED' => FactoryBadgeVariant.available,
      'COMPLETED' => FactoryBadgeVariant.verified,
      'CANCELLED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

String _bookingStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'CONFIRMED' => l10n.bookingStatusConfirmed,
      'COMPLETED' => l10n.bookingStatusCompleted,
      'CANCELLED' => l10n.bookingStatusCancelled,
      _ => _capitalize(status),
    };

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

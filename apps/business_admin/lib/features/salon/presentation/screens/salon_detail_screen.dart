import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../core/image/pick_and_crop_image.dart';
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
import '../../../cleaning/data/models/admin_cleaner.dart';
import '../../../cleaning/presentation/providers/cleaning_admin_providers.dart';
import '../../../cleaning/presentation/widgets/add_cleaner_dialog.dart';
import '../../../cleaning/presentation/widgets/manage_cleaner_services_dialog.dart';
import '../../../staff/data/models/admin_staff.dart';
import '../../../staff/presentation/providers/staff_admin_providers.dart';
import '../../../staff/presentation/widgets/add_staff_dialog.dart';
import '../../../staff/presentation/widgets/manage_staff_services_dialog.dart';
import '../../../reviews/presentation/screens/reviews_screen.dart';
import '../../../storage/presentation/providers/storage_providers.dart';
import '../../data/models/admin_booking.dart';
import '../../data/models/admin_payout.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/admin_service.dart';
import '../../data/models/admin_slot.dart';
import '../providers/salon_providers.dart';
import '../widgets/add_service_dialog.dart';
import '../widgets/recurring_schedule_dialog.dart';
import 'business_analytics_screen.dart';

/// Categories with their own hardcoded staff module (Master/Mechanic/
/// Cleaner) — every other category falls back to the generic `staff`
/// module below, so a platform admin's brand-new category gets a working
/// staff section immediately, with no app release.
const _verticalsWithDedicatedStaffModule = {'beauty', 'auto', 'cleaning'};

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
            icon: const Icon(Icons.star_outline_rounded),
            tooltip: l10n.reviewsTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(providerId: _provider.id, providerName: _provider.name),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: l10n.businessAnalyticsTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BusinessAnalyticsScreen(provider: _provider)),
              );
            },
          ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidates every argument-instance of each family (not just
          // this provider's, and regardless of a section's current
          // show-inactive toggle) — simpler and just as correct as threading
          // every section's local state up here, since re-fetching another
          // salon's already-cached data too costs nothing a user notices.
          ref.invalidate(providerDashboardMetricsProvider);
          ref.invalidate(providerServicesProvider);
          ref.invalidate(providerSlotsProvider);
          ref.invalidate(adminMastersProvider);
          ref.invalidate(adminMechanicsProvider);
          ref.invalidate(adminCleanersProvider);
          ref.invalidate(adminStaffProvider);
          ref.invalidate(providerBookingsProvider);
          ref.invalidate(providerPayoutsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            _BusinessHeader(
              provider: _provider,
              statusLabel: _providerStatusLabel(l10n, _provider.status),
              statusVariant: _providerStatusVariant(_provider.status),
            ),
            const SizedBox(height: FactorySpacing.space6),
            _DashboardMetricsSection(providerId: _provider.id),
            const SizedBox(height: FactorySpacing.space6),
            _ServicesSection(providerId: _provider.id, businessTypeId: _provider.businessTypeId),
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
            if (_provider.vertical == 'cleaning') ...[
              const SizedBox(height: FactorySpacing.space6),
              _CleanersSection(providerId: _provider.id),
            ],
            if (!_verticalsWithDedicatedStaffModule.contains(_provider.vertical)) ...[
              const SizedBox(height: FactorySpacing.space6),
              _StaffSection(providerId: _provider.id),
            ],
            const SizedBox(height: FactorySpacing.space6),
            _BookingsSection(providerId: _provider.id),
            const SizedBox(height: FactorySpacing.space6),
            _BookingSettingsSection(providerId: _provider.id),
            const SizedBox(height: FactorySpacing.space6),
            _PayoutsSection(providerId: _provider.id),
          ],
        ),
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

  /// Local pick, not yet uploaded — the upload only happens on submit
  /// (mirrors AddPortfolioItemDialog), so a cancelled dialog never leaves
  /// an orphaned file in storage. Null means "keep whatever
  /// widget.provider.coverPhotoUrl already is", not "remove the photo" —
  /// this dialog has no explicit "remove photo" affordance yet.
  Uint8List? _pickedPhotoBytes;
  String? _pickedPhotoName;

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: FactorySpacing.space3),
          Text(l10n.coverPhotoLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: FactorySpacing.space2),
          if (_pickedPhotoBytes != null) ...[
            ClipRRect(
              borderRadius: FactoryRadius.mdRadius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(_pickedPhotoBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: FactorySpacing.space2),
          ],
          FactoryButton(
            icon: Icons.image_outlined,
            label: _pickedPhotoName ?? l10n.choosePhotoLabel,
            variant: FactoryButtonVariant.secondary,
            onPressed: _isSubmitting ? null : _pickPhoto,
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

  Future<void> _pickPhoto() async {
    try {
      // 16:9, not the square lock most other pickers in this app use — a
      // cover photo is a wide banner, not an avatar.
      final picked = await pickAndCropImage(
        context,
        cropTitle: AppLocalizations.of(context)!.coverPhotoLabel,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      );
      if (picked == null) return;
      setState(() {
        _pickedPhotoBytes = picked.bytes;
        _pickedPhotoName = picked.name;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.errorReadFileFailed(e.toString()));
    }
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
      // Only upload if the owner picked a new photo this session — PUT is
      // a full overwrite (Provider.update sets whatever's sent), so an
      // unchanged pick must still resend the existing coverPhotoUrl rather
      // than sending null and clearing it.
      String? coverPhotoUrl = widget.provider.coverPhotoUrl;
      final bytes = _pickedPhotoBytes;
      final name0 = _pickedPhotoName;
      if (bytes != null && name0 != null) {
        final uploaded = await ref.read(storageApiProvider).uploadBytes(bytes, name0);
        coverPhotoUrl = uploaded.url;
      }
      final updated = await ref.read(salonAdminApiProvider).updateProvider(
            providerId: widget.provider.id,
            name: name,
            latitude: lat,
            longitude: lng,
            coverPhotoUrl: coverPhotoUrl,
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

/// Generic photo-change dialog shared by the master/mechanic/cleaner/staff
/// rows below — each just passes its own `onSave` calling the matching
/// admin API's updateXPhoto. Mirrors _EditSalonDialog's pick-then-upload
/// pattern (upload only happens on submit, so a cancelled dialog never
/// leaves an orphaned file in storage).
Future<void> _showChangePhotoDialog(
  BuildContext context, {
  required bool hasCurrentPhoto,
  required Future<void> Function(String? photoUrl) onSave,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ChangePhotoDialog(hasCurrentPhoto: hasCurrentPhoto, onSave: onSave),
  );
}

class _ChangePhotoDialog extends ConsumerStatefulWidget {
  const _ChangePhotoDialog({required this.hasCurrentPhoto, required this.onSave});

  final bool hasCurrentPhoto;
  final Future<void> Function(String? photoUrl) onSave;

  @override
  ConsumerState<_ChangePhotoDialog> createState() => _ChangePhotoDialogState();
}

class _ChangePhotoDialogState extends ConsumerState<_ChangePhotoDialog> {
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _isSubmitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pickedBytes = _pickedBytes;
    return FactoryDialog(
      title: l10n.changePhotoDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (pickedBytes != null) ...[
            CircleAvatar(radius: 48, backgroundImage: MemoryImage(pickedBytes)),
            const SizedBox(height: FactorySpacing.space3),
          ],
          FactoryButton(
            icon: Icons.image_outlined,
            label: l10n.choosePhotoLabel,
            variant: FactoryButtonVariant.secondary,
            onPressed: _isSubmitting ? null : _pickPhoto,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        if (widget.hasCurrentPhoto)
          FactoryButton(
            label: l10n.removePhotoButton,
            variant: FactoryButtonVariant.text,
            onPressed: _isSubmitting ? null : _removePhoto,
          ),
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.saveButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting || _pickedBytes == null ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickAndCropImage(context, cropTitle: AppLocalizations.of(context)!.changePhotoDialogTitle);
      if (picked == null) return;
      setState(() {
        _pickedBytes = picked.bytes;
        _pickedName = picked.name;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.errorReadFileFailed(e.toString()));
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSave(null);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.errorUpdatePhotoFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submit() async {
    final bytes = _pickedBytes;
    final name = _pickedName;
    if (bytes == null || name == null) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final uploaded = await ref.read(storageApiProvider).uploadBytes(bytes, name);
      await widget.onSave(uploaded.url);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.errorUpdatePhotoFailed(e.toString());
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
                _MetricsBento(
                  revenueLabel: l10n.dashboardTotalRevenueLabel,
                  revenue: metrics.totalRevenue,
                  totalLabel: l10n.dashboardTotalBookingsLabel,
                  total: metrics.totalBookings,
                  averageLabel: l10n.dashboardAverageCheckLabel,
                  average: metrics.averageCheck,
                  completedLabel: l10n.dashboardCompletedBookingsLabel,
                  completed: metrics.completedBookings,
                  cancelledLabel: l10n.dashboardCancelledBookingsLabel,
                  cancelled: metrics.cancelledBookings,
                  cancellationLabel: l10n.dashboardCancellationRateLabel,
                  cancellationRate: metrics.cancellationRate,
                  customersLabel: l10n.dashboardTotalCustomersLabel,
                  customers: metrics.totalCustomers,
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

/// Photo-first header: the cover photo under a soft scrim (or a tinted
/// gradient with the vertical's icon while there is none), with the vertical
/// and status badges on top. The name stays in the app bar.
class _BusinessHeader extends StatelessWidget {
  final AdminProvider provider;
  final String statusLabel;
  final FactoryBadgeVariant statusVariant;

  const _BusinessHeader({required this.provider, required this.statusLabel, required this.statusVariant});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    final photo = provider.coverPhotoUrl;
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
            'auto' => Icons.directions_car_filled_outlined,
            'cleaning' => Icons.cleaning_services_outlined,
            _ => Icons.content_cut_rounded,
          },
          size: 48,
          color: colors.primaryStrong.withValues(alpha: 0.5),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo == null)
              fallback
            else
              Image.network(photo, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => fallback),
            if (photo != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x55000000)],
                  ),
                ),
              ),
            Positioned(
              left: FactorySpacing.space3,
              bottom: FactorySpacing.space3,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FactoryBadge(label: _capitalize(provider.vertical)),
                  FactoryBadge(label: statusLabel, variant: statusVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bento for the business overview: revenue is the one big number (with the
/// total and average ticket under it); completed / cancelled / customers are
/// tiles and the cancellation rate is a ring, warning-colored because for a
/// cancellation rate lower is better.
class _MetricsBento extends StatelessWidget {
  final String revenueLabel;
  final num revenue;
  final String totalLabel;
  final int total;
  final String averageLabel;
  final num? average;
  final String completedLabel;
  final int completed;
  final String cancelledLabel;
  final int cancelled;
  final String cancellationLabel;
  final double cancellationRate;
  final String customersLabel;
  final int customers;

  const _MetricsBento({
    required this.revenueLabel,
    required this.revenue,
    required this.totalLabel,
    required this.total,
    required this.averageLabel,
    required this.average,
    required this.completedLabel,
    required this.completed,
    required this.cancelledLabel,
    required this.cancelled,
    required this.cancellationLabel,
    required this.cancellationRate,
    required this.customersLabel,
    required this.customers,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.xlRadius;
    final muted = colors.onPrimary.withValues(alpha: 0.8);
    const gap = SizedBox(height: FactorySpacing.space3);
    const hgap = SizedBox(width: FactorySpacing.space3);

    Widget tile(String label, String value) => Expanded(
      child: FactoryCard(
        padding: const EdgeInsets.all(FactorySpacing.space3),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(FactorySpacing.space5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.primaryStrong, colors.primary],
            ),
            borderRadius: radius,
            boxShadow: context.factoryElevation(FactoryElevationLevel.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(revenueLabel, style: textTheme.labelLarge?.copyWith(color: muted)),
              const SizedBox(height: FactorySpacing.space1),
              FactoryPriceText(amount: revenue, fontSize: 30, color: colors.onPrimary),
              const SizedBox(height: FactorySpacing.space4),
              Wrap(
                spacing: FactorySpacing.space6,
                runSpacing: FactorySpacing.space2,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total', style: textTheme.titleMedium?.copyWith(color: colors.onPrimary)),
                      Text(totalLabel, style: textTheme.labelMedium?.copyWith(color: muted)),
                    ],
                  ),
                  if (average != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FactoryPriceText(amount: average!, fontSize: 16, color: colors.onPrimary),
                        Text(averageLabel, style: textTheme.labelMedium?.copyWith(color: muted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [tile(completedLabel, '$completed'), hgap, tile(cancelledLabel, '$cancelled')],
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            tile(customersLabel, '$customers'),
            hgap,
            Expanded(
              child: FactoryCard(
                padding: const EdgeInsets.all(FactorySpacing.space3),
                child: Row(
                  children: [
                    FactoryProgressRing(
                      value: cancellationRate,
                      size: 44,
                      strokeWidth: 6,
                      color: colors.warning,
                      semanticLabel: cancellationLabel,
                      child: Text(
                        '${(cancellationRate * 100).round()}%',
                        style: FactoryTypography.mono(size: 10, color: colors.text),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space2),
                    Expanded(
                      child: Text(
                        cancellationLabel,
                        style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  final String providerId;
  final String? businessTypeId;

  const _ServicesSection({required this.providerId, this.businessTypeId});

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
                    builder: (_) => AddServiceDialog(providerId: providerId, businessTypeId: businessTypeId),
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
                            builder: (_) => AddServiceDialog(providerId: providerId, businessTypeId: businessTypeId, existing: s),
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

class _AvailabilitySection extends ConsumerStatefulWidget {
  final String providerId;

  const _AvailabilitySection({required this.providerId});

  @override
  ConsumerState<_AvailabilitySection> createState() => _AvailabilitySectionState();
}

class _AvailabilitySectionState extends ConsumerState<_AvailabilitySection> {
  /// A recurring schedule can span weeks; show the nearest days and let the
  /// owner expand the rest instead of rendering hundreds of chips at once.
  static const _initialDays = 7;
  bool _showAll = false;

  String get providerId => widget.providerId;

  @override
  Widget build(BuildContext context) {
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
            final byDay = groupByLocalDay<AdminSlot>(slots, (s) => s.startsAt);
            final days = byDay.keys.toList();
            final shown = _showAll ? days : days.take(_initialDays).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++)
                  _DaySlots(
                    key: ValueKey(shown[i]),
                    day: shown[i],
                    slots: byDay[shown[i]]!,
                    initiallyExpanded: i == 0,
                    onDelete: (slot) async {
                      await ref.read(salonAdminApiProvider).deleteSlot(slot.id);
                      ref.invalidate(providerSlotsProvider(providerId));
                    },
                  ),
                if (days.length > _initialDays)
                  FactoryButton(
                    label: _showAll
                        ? l10n.slotsDaysShowLess
                        : l10n.slotsDaysShowAll(days.length - _initialDays),
                    variant: FactoryButtonVariant.text,
                    onPressed: () => setState(() => _showAll = !_showAll),
                  ),
              ],
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

/// One day of availability: collapsed to "6 open · 2 booked", expanded to the
/// day's times.
class _DaySlots extends StatelessWidget {
  final DateTime day;
  final List<AdminSlot> slots;
  final bool initiallyExpanded;
  final Future<void> Function(AdminSlot slot) onDelete;

  const _DaySlots({
    super.key,
    required this.day,
    required this.slots,
    required this.initiallyExpanded,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final open = slots.where((s) => s.status == 'OPEN').length;

    return Container(
      margin: const EdgeInsets.only(bottom: FactorySpacing.space2),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: FactoryRadius.mdRadius,
      ),
      child: ClipRRect(
        borderRadius: FactoryRadius.mdRadius,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            formatWeekdayMonthDay(l10n, day),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            l10n.slotsDaySummary(open, slots.length - open),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            FactorySpacing.space3,
            0,
            FactorySpacing.space3,
            FactorySpacing.space3,
          ),
          expandedAlignment: Alignment.centerLeft,
          children: [
            // Only an OPEN slot can be removed (see backend's
            // AvailabilitySlotController.delete()) — a booked one keeps
            // its chip but with no delete affordance.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in slots)
                  Chip(
                    label: Text(
                      s.status == 'OPEN'
                          ? formatHourMinute(s.startsAt.toLocal())
                          : '${formatHourMinute(s.startsAt.toLocal())} · ${_capitalize(s.status)}',
                    ),
                    onDeleted: s.status == 'OPEN' ? () => onDelete(s) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
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
                          onChangePhoto: () => _showChangePhotoDialog(
                            context,
                            hasCurrentPhoto: m.photoUrl != null,
                            onSave: (photoUrl) async {
                              await ref.read(beautyAdminApiProvider).updateMasterPhoto(m.id, photoUrl);
                              refresh();
                            },
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
    required this.onChangePhoto,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminMaster master;
  final VoidCallback onManageServices;
  final VoidCallback onAddPortfolioItem;
  final VoidCallback onChangePhoto;
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
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: l10n.changePhotoTooltip,
                  onPressed: onChangePhoto,
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
                          onChangePhoto: () => _showChangePhotoDialog(
                            context,
                            hasCurrentPhoto: m.photoUrl != null,
                            onSave: (photoUrl) async {
                              await ref.read(autoAdminApiProvider).updateMechanicPhoto(m.id, photoUrl);
                              refresh();
                            },
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
    required this.onChangePhoto,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminMechanic mechanic;
  final VoidCallback onManageServices;
  final VoidCallback onChangePhoto;
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
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: l10n.changePhotoTooltip,
                  onPressed: onChangePhoto,
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

class _CleanersSection extends ConsumerWidget {
  final String providerId;

  const _CleanersSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final showInactive = ref.watch(showInactiveCleanersProvider(providerId));
    final cleanersAsync = ref.watch(adminCleanersProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(adminCleanersProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.cleanersSectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                label: showInactive ? l10n.hideRemovedButton : l10n.showRemovedButton,
                variant: FactoryButtonVariant.text,
                onPressed: () =>
                    ref.read(showInactiveCleanersProvider(providerId).notifier).state = !showInactive,
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddCleanerDialog(providerId: providerId),
                  );
                  if (added == true) refresh();
                },
              ),
            ],
          ),
        ),
        cleanersAsync.when(
          data: (cleaners) {
            if (cleaners.isEmpty) {
              return Text(
                showInactive ? l10n.noCleanersYet : l10n.noActiveCleaners,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: cleaners
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _CleanerAdminRow(
                          cleaner: c,
                          onManageServices: () => showDialog(
                            context: context,
                            builder: (_) => ManageCleanerServicesDialog(providerId: providerId, cleanerId: c.id),
                          ),
                          onChangePhoto: () => _showChangePhotoDialog(
                            context,
                            hasCurrentPhoto: c.photoUrl != null,
                            onSave: (photoUrl) async {
                              await ref.read(cleaningAdminApiProvider).updateCleanerPhoto(c.id, photoUrl);
                              refresh();
                            },
                          ),
                          onRemove: () async {
                            await ref.read(cleaningAdminApiProvider).deactivateCleaner(c.id);
                            refresh();
                          },
                          onReactivate: () async {
                            await ref.read(cleaningAdminApiProvider).reactivateCleaner(c.id);
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
          error: (error, stackTrace) => Text(l10n.errorCleanersLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _CleanerAdminRow extends StatelessWidget {
  const _CleanerAdminRow({
    required this.cleaner,
    required this.onManageServices,
    required this.onChangePhoto,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminCleaner cleaner;
  final VoidCallback onManageServices;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemove;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: _initialsFor(cleaner.displayName),
        image: cleaner.photoUrl != null ? NetworkImage(cleaner.photoUrl!) : null,
      ),
      title: cleaner.displayName,
      titleColor: cleaner.active ? null : colors.textTertiary,
      subtitle: cleaner.bio != null
          ? Text(
              cleaner.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      trailing: cleaner.active
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.design_services_outlined),
                  tooltip: l10n.manageCleanerServicesTooltip,
                  onPressed: onManageServices,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: l10n.changePhotoTooltip,
                  onPressed: onChangePhoto,
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.removeCleanerTooltip,
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

class _StaffSection extends ConsumerWidget {
  final String providerId;

  const _StaffSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final showInactive = ref.watch(showInactiveStaffProvider(providerId));
    final staffAsync = ref.watch(adminStaffProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(adminStaffProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(
          title: l10n.staffSectionTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FactoryButton(
                label: showInactive ? l10n.hideRemovedButton : l10n.showRemovedButton,
                variant: FactoryButtonVariant.text,
                onPressed: () =>
                    ref.read(showInactiveStaffProvider(providerId).notifier).state = !showInactive,
              ),
              FactoryButton(
                icon: Icons.add,
                label: l10n.addButton,
                variant: FactoryButtonVariant.text,
                onPressed: () async {
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => AddStaffDialog(providerId: providerId),
                  );
                  if (added == true) refresh();
                },
              ),
            ],
          ),
        ),
        staffAsync.when(
          data: (staff) {
            if (staff.isEmpty) {
              return Text(
                showInactive ? l10n.noStaffYet : l10n.noActiveStaff,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(
              children: staff
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _StaffAdminRow(
                          staff: s,
                          onManageServices: () => showDialog(
                            context: context,
                            builder: (_) => ManageStaffServicesDialog(providerId: providerId, staffId: s.id),
                          ),
                          onChangePhoto: () => _showChangePhotoDialog(
                            context,
                            hasCurrentPhoto: s.photoUrl != null,
                            onSave: (photoUrl) async {
                              await ref.read(staffAdminApiProvider).updateStaffPhoto(s.id, photoUrl);
                              refresh();
                            },
                          ),
                          onRemove: () async {
                            await ref.read(staffAdminApiProvider).deactivateStaff(s.id);
                            refresh();
                          },
                          onReactivate: () async {
                            await ref.read(staffAdminApiProvider).reactivateStaff(s.id);
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
          error: (error, stackTrace) => Text(l10n.errorStaffLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _StaffAdminRow extends StatelessWidget {
  const _StaffAdminRow({
    required this.staff,
    required this.onManageServices,
    required this.onChangePhoto,
    required this.onRemove,
    required this.onReactivate,
  });

  final AdminStaff staff;
  final VoidCallback onManageServices;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemove;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: _initialsFor(staff.displayName),
        image: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
      ),
      title: staff.displayName,
      titleColor: staff.active ? null : colors.textTertiary,
      subtitle: staff.bio != null
          ? Text(
              staff.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            )
          : null,
      trailing: staff.active
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.design_services_outlined),
                  tooltip: l10n.manageStaffServicesTooltip,
                  onPressed: onManageServices,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: l10n.changePhotoTooltip,
                  onPressed: onChangePhoto,
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: l10n.removeStaffTooltip,
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

/// The business's own settlement visibility — see ADR-0007
/// (docs/adr/0007-marketplace-commission-and-settlement.md). Read-only: a
/// business can see what it's owed and whether it's been paid, but never
/// marks its own payout PAID — that's a platform-admin-only action, done
/// outside this app.
class _PayoutsSection extends ConsumerWidget {
  final String providerId;

  const _PayoutsSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final payoutsAsync = ref.watch(providerPayoutsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.payoutsSectionTitle),
        const SizedBox(height: FactorySpacing.space2),
        payoutsAsync.when(
          data: (payouts) {
            if (payouts.isEmpty) {
              return Text(
                l10n.noPayoutsYet,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              );
            }
            return Column(children: payouts.map((p) => _PayoutAdminRow(payout: p)).toList());
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text(l10n.errorPayoutsLoadFailed(error.toString())),
        ),
      ],
    );
  }
}

class _PayoutAdminRow extends StatelessWidget {
  const _PayoutAdminRow({required this.payout});

  final AdminPayout payout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FactoryPriceText(amount: payout.amount, fontSize: 14),
              FactoryBadge(
                label: _payoutStatusLabel(l10n, payout.status),
                variant: _payoutStatusVariant(payout.status),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            payout.settledAt != null
                ? formatMonthDayTime(l10n, payout.settledAt!.toLocal())
                : formatMonthDayTime(l10n, payout.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

FactoryBadgeVariant _payoutStatusVariant(String status) => switch (status) {
      'PAID' => FactoryBadgeVariant.verified,
      'PROCESSING' => FactoryBadgeVariant.limited,
      'FAILED' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

String _payoutStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'PAYABLE' => l10n.payoutStatusPayable,
      'PROCESSING' => l10n.payoutStatusProcessing,
      'PAID' => l10n.payoutStatusPaid,
      'FAILED' => l10n.payoutStatusFailed,
      _ => _capitalize(status),
    };

class _BookingSettingsSection extends ConsumerStatefulWidget {
  final String providerId;

  const _BookingSettingsSection({required this.providerId});

  @override
  ConsumerState<_BookingSettingsSection> createState() => _BookingSettingsSectionState();
}

enum _DepositMode { none, deposit, full }

class _BookingSettingsSectionState extends ConsumerState<_BookingSettingsSection> {
  late final _depositPercentageController = TextEditingController(text: '10');
  _DepositMode _mode = _DepositMode.none;
  bool _isEditing = true;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(salonAdminApiProvider).getDepositPercentage(widget.providerId);
      if (!mounted) return;
      setState(() {
        if (value <= 0) {
          _mode = _DepositMode.none;
        } else if (value >= 100) {
          _mode = _DepositMode.full;
        } else {
          _mode = _DepositMode.deposit;
          _depositPercentageController.text = '$value';
        }
      });
    } catch (_) {
      // Keep the default; the owner can still pick an option and save it.
    } finally {
      if (mounted) setState(() => _isEditing = false);
    }
  }

  @override
  void dispose() {
    _depositPercentageController.dispose();
    super.dispose();
  }

  /// 0 = no prepayment, 100 = full payment, 1-99 = deposit — the same scale
  /// the backend stores.
  int get _effectivePercentage => switch (_mode) {
        _DepositMode.none => 0,
        _DepositMode.full => 100,
        _DepositMode.deposit => int.tryParse(_depositPercentageController.text.trim()) ?? 0,
      };

  Widget _modeTile(String title, String subtitle, _DepositMode mode) {
    final colors = context.factoryColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
      child: FactorySelectableTile(
        title: title,
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
        selected: _mode == mode,
        onTap: _isEditing
            ? null
            : () => setState(() {
                  _mode = mode;
                  _fieldError = null;
                }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactorySectionHeader(title: l10n.bookingSettingsTitle),
        const SizedBox(height: FactorySpacing.space3),
        FactoryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.depositModeTitle,
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: FactorySpacing.space2),
              _modeTile(l10n.depositModeNone, l10n.depositModeNoneHint, _DepositMode.none),
              _modeTile(l10n.depositModeDeposit, l10n.depositModeDepositHint, _DepositMode.deposit),
              _modeTile(l10n.depositModeFull, l10n.depositModeFullHint, _DepositMode.full),
              if (_mode == _DepositMode.deposit) ...[
                const SizedBox(height: FactorySpacing.space1),
                FactoryTextField(
                  controller: _depositPercentageController,
                  label: l10n.depositPercentageLabel,
                  hint: l10n.depositPercentageRangeHint,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  enabled: !_isEditing,
                  errorText: _fieldError,
                  onChanged: (_) => setState(() => _fieldError = null),
                ),
              ],
              const SizedBox(height: FactorySpacing.space3),
              _DepositPercentageGuide(percentage: _effectivePercentage),
              const SizedBox(height: FactorySpacing.space3),
              Align(
                alignment: Alignment.centerRight,
                child: FactoryButton(
                  label: l10n.saveButton,
                  isLoading: _isEditing,
                  onPressed: _isEditing ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final value = _effectivePercentage;

    if (_mode == _DepositMode.deposit && (value < 1 || value > 99)) {
      setState(() => _fieldError = l10n.validationDepositPercentageRange);
      return;
    }

    setState(() => _isEditing = true);
    try {
      await ref.read(salonAdminApiProvider).setDepositPercentage(widget.providerId, value);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.depositPercentageSaved)),
      );
      setState(() {
        _isEditing = false;
        _fieldError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSaveBusinessFailed(e.toString()))),
      );
      setState(() => _isEditing = false);
    }
  }
}

class _DepositPercentageGuide extends StatelessWidget {
  final int percentage;

  const _DepositPercentageGuide({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100.0,
                  minHeight: 8,
                  backgroundColor: colors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage == 0
                      ? colors.textTertiary
                      : percentage < 50
                        ? colors.warning
                        : colors.success,
                  ),
                ),
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
            Text(
              '$percentage%',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

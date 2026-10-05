import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/models/catalog_service.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/models/admin_service.dart';
import '../providers/salon_providers.dart';

/// Add-or-edit: pass [existing] to edit that service in place instead of
/// creating a new one. Returns true via Navigator.pop on success — the
/// caller invalidates providerServicesProvider in response, same pattern
/// as apps/user_app's _LeaveReviewDialog.
///
/// When the business has a catalog business type ([businessTypeId]) the service
/// is picked from the platform-managed catalog instead of typed in: the title is
/// the catalog name in the owner's language and the offering is created (or
/// updated) already linked to its catalog entry — the backend enforces this, so
/// a business can't write its own service names. Businesses that predate the
/// catalog (no business type) keep the free-text title.
class AddServiceDialog extends ConsumerStatefulWidget {
  final String providerId;
  final String? businessTypeId;
  final AdminService? existing;

  const AddServiceDialog({super.key, required this.providerId, this.businessTypeId, this.existing});

  @override
  ConsumerState<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialog> {
  /// A service keeps its own currency when edited; a new one takes the
  /// platform's current market currency instead of a hardcoded one.
  String get _currency => widget.existing?.currency ?? RegionDefaults.country.currency;

  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _durationController =
      TextEditingController(text: (widget.existing?.durationMinutes ?? 30).toString());
  late final _priceController = TextEditingController(text: widget.existing?.price.toString() ?? '');
  bool _isSubmitting = false;
  String? _error;
  late String? _catalogServiceId = widget.existing?.catalogServiceId;
  List<CatalogServiceModel> _catalogServices = const [];

  bool get _usesCatalog => widget.businessTypeId != null;

  String get _languageCode => Localizations.localeOf(context).languageCode;

  CatalogServiceModel? get _selectedCatalogService {
    for (final service in _catalogServices) {
      if (service.id == _catalogServiceId) return service;
    }
    return null;
  }

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: _isEditing ? l10n.editServiceDialogTitle : l10n.addServiceDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_usesCatalog)
            _buildCatalogPicker(l10n)
          else
            FactoryTextField(
              controller: _titleController,
              enabled: !_isSubmitting,
              label: l10n.titleLabel,
            ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _durationController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            label: l10n.durationMinutesLabel,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _priceController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            label: l10n.priceLabel(currencySymbolFor(_currency)),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(
          label: _isEditing ? l10n.saveButton : l10n.addButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _buildCatalogPicker(AppLocalizations l10n) {
    final servicesAsync = ref.watch(catalogServicesProvider(widget.businessTypeId!));
    final subspheres = ref.watch(subspheresProvider(widget.businessTypeId!)).value ?? const [];
    final subsphereNames = {for (final s in subspheres) s.id: s.nameFor(_languageCode)};
    final subsphereOrder = {for (final s in subspheres) s.id: s.sortOrder};

    return servicesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(FactorySpacing.space2),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        l10n.errorCatalogServicesLoad(error.toString()),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (services) {
        // Group by subsphere (its sort order, services without one first), then
        // by the catalog's own order; the group name prefixes each entry.
        final sorted = [...services]..sort((a, b) {
            final byGroup = (subsphereOrder[a.subsphereId] ?? -1).compareTo(subsphereOrder[b.subsphereId] ?? -1);
            return byGroup != 0 ? byGroup : a.sortOrder.compareTo(b.sortOrder);
          });
        _catalogServices = sorted;
        final selected = sorted.any((s) => s.id == _catalogServiceId) ? _catalogServiceId : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.catalogServiceLabel),
          items: [
            for (final service in sorted)
              DropdownMenuItem(
                value: service.id,
                child: Text(
                  subsphereNames[service.subsphereId] == null
                      ? service.nameFor(_languageCode)
                      : '${subsphereNames[service.subsphereId]} · ${service.nameFor(_languageCode)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _isSubmitting ? null : (value) => setState(() => _catalogServiceId = value),
        );
      },
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final catalogService = _usesCatalog ? _selectedCatalogService : null;
    // With a catalog business type the service must be one the platform
    // defined — also when editing an older, free-text one — so nothing is
    // submitted until an entry is picked.
    final title = catalogService?.nameFor(_languageCode) ?? (_usesCatalog ? '' : _titleController.text.trim());
    final duration = int.tryParse(_durationController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (title.isEmpty || duration == null || duration <= 0 || price == null || price < 0) {
      setState(() => _error = _usesCatalog ? l10n.validationPickCatalogService : l10n.validationServiceFields);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final api = ref.read(salonAdminApiProvider);
      if (_isEditing) {
        await api.updateService(
          serviceId: widget.existing!.id,
          title: title,
          durationMinutes: duration,
          price: price,
          currency: _currency,
          catalogServiceId: catalogService?.id,
        );
      } else {
        await api.createService(
          providerId: widget.providerId,
          title: title,
          durationMinutes: duration,
          price: price,
          currency: _currency,
          catalogServiceId: catalogService?.id,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = _isEditing ? l10n.errorServiceSaveFailed(e.toString()) : l10n.errorServiceAddFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

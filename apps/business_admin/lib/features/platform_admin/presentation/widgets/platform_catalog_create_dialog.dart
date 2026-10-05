import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/models/subsphere.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../platform_admin_labels.dart';

/// The four rows of the master catalog, top to bottom.
enum CatalogLevel { category, sphere, subsphere, service }

/// One dialog for creating any catalog row. [parentId] is the category (for a
/// sphere), the sphere (for a subsphere or service); [parentName] is only for
/// the title. A category has no parent.
///
/// The code is filled in from the English name as the person types, until
/// they edit it by hand — nobody should have to invent an identifier just to
/// add a service. Pops with the created item's English name, so the caller
/// can confirm it.
class PlatformCatalogCreateDialog extends ConsumerStatefulWidget {
  const PlatformCatalogCreateDialog({
    super.key,
    required this.platformToken,
    required this.level,
    this.parentId,
    this.parentName,
  });

  final String platformToken;
  final CatalogLevel level;
  final String? parentId;
  final String? parentName;

  @override
  ConsumerState<PlatformCatalogCreateDialog> createState() => _PlatformCatalogCreateDialogState();
}

class _PlatformCatalogCreateDialogState extends ConsumerState<PlatformCatalogCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameEn = TextEditingController();
  final _nameRu = TextEditingController();
  final _nameKk = TextEditingController();
  final _code = TextEditingController();
  final _icon = TextEditingController();
  Subsphere? _subsphere;
  bool _codeEditedByHand = false;
  bool _isSubmitting = false;
  String? _error;

  bool get _hasCode => widget.level != CatalogLevel.service;

  @override
  void dispose() {
    _nameEn.dispose();
    _nameRu.dispose();
    _nameKk.dispose();
    _code.dispose();
    _icon.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l10n) => switch (widget.level) {
    CatalogLevel.category => l10n.paAddCategory,
    CatalogLevel.sphere => l10n.paNewSphereTitle(widget.parentName ?? ''),
    CatalogLevel.subsphere => l10n.paNewSubsphereTitle(widget.parentName ?? ''),
    CatalogLevel.service => l10n.paNewServiceTitle(widget.parentName ?? ''),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    String? required(String? value) => (value == null || value.trim().isEmpty) ? l10n.paFieldRequired : null;
    const gap = SizedBox(height: FactorySpacing.space3);

    return FactoryDialog(
      title: _title(l10n),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _nameEn,
                  enabled: !_isSubmitting,
                  label: l10n.paFieldNameEn,
                  textInputAction: TextInputAction.next,
                  validator: required,
                  onChanged: (value) {
                    if (_hasCode && !_codeEditedByHand) _code.text = slugifyCode(value);
                  },
                ),
                gap,
                FactoryTextField(
                  controller: _nameRu,
                  enabled: !_isSubmitting,
                  label: l10n.paFieldNameRu,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                gap,
                FactoryTextField(
                  controller: _nameKk,
                  enabled: !_isSubmitting,
                  label: l10n.paFieldNameKk,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                if (widget.level == CatalogLevel.category) ...[
                  gap,
                  FactoryTextField(controller: _icon, enabled: !_isSubmitting, label: l10n.paFieldIcon),
                ],
                if (widget.level == CatalogLevel.service) ...[gap, _subspherePicker(l10n, languageCode)],
                if (_hasCode) ...[
                  gap,
                  FactoryTextField(
                    controller: _code,
                    enabled: !_isSubmitting,
                    label: l10n.paFieldCode,
                    onChanged: (_) => _codeEditedByHand = true,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return l10n.paFieldRequired;
                      return isValidCatalogCode(text) ? null : l10n.paFieldCodeInvalid;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space1),
                    child: Text(l10n.paFieldCodeHelper, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space3),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Widget _subspherePicker(AppLocalizations l10n, String languageCode) {
    final subspheres = ref.watch(platformAllSubspheresProvider((widget.platformToken, widget.parentId!))).value ?? [];
    if (subspheres.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<Subsphere?>(
      initialValue: _subsphere,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.paFieldSubsphereOptional),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.paSubsphereNone, overflow: TextOverflow.ellipsis)),
        for (final subsphere in subspheres)
          DropdownMenuItem(value: subsphere, child: Text(subsphere.nameFor(languageCode))),
      ],
      onChanged: _isSubmitting ? null : (value) => setState(() => _subsphere = value),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final api = ref.read(catalogApiProvider);
    final token = widget.platformToken;
    final nameEn = _nameEn.text.trim();
    final nameRu = _nameRu.text.trim();
    final nameKk = _nameKk.text.trim();
    final code = _code.text.trim();
    try {
      switch (widget.level) {
        case CatalogLevel.category:
          final icon = _icon.text.trim();
          await api.createCategory(
            token,
            code: code,
            nameKk: nameKk,
            nameRu: nameRu,
            nameEn: nameEn,
            icon: icon.isEmpty ? null : icon,
            sortOrder: 100,
          );
        case CatalogLevel.sphere:
          await api.createBusinessType(
            token,
            categoryId: widget.parentId!,
            code: code,
            nameKk: nameKk,
            nameRu: nameRu,
            nameEn: nameEn,
            sortOrder: 100,
          );
        case CatalogLevel.subsphere:
          await api.createSubsphere(
            token,
            businessTypeId: widget.parentId!,
            code: code,
            nameKk: nameKk,
            nameRu: nameRu,
            nameEn: nameEn,
            sortOrder: 100,
          );
        case CatalogLevel.service:
          await api.createCatalogService(
            token,
            businessTypeId: widget.parentId!,
            subsphereId: _subsphere?.id,
            nameKk: nameKk,
            nameRu: nameRu,
            nameEn: nameEn,
            sortOrder: 100,
          );
      }
      if (mounted) Navigator.of(context).pop(nameEn);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = error is DioException && error.response?.statusCode == 409 ? l10n.paCodeTaken : l10n.paActionFailed;
        _isSubmitting = false;
      });
    }
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/catalog_api.dart';
import '../data/catalog_models.dart';

/// One dialog to create or edit a catalog row at any level.
///
/// Creating: the code is filled in from the English name as the person types,
/// until they edit it by hand — nobody should invent an identifier just to add
/// a service. Editing: the code is shown but fixed (other data refers to it).
/// Pops with the saved row's English name so the caller can confirm it.
class CatalogEditDialog extends ConsumerStatefulWidget {
  const CatalogEditDialog({
    super.key,
    required this.level,
    this.node,
    this.parentId,
    this.parentName,
    this.suggestedPosition = 10,
    this.subspheres = const [],
  });

  final CatalogLevel level;

  /// Set when editing.
  final CatalogNode? node;

  /// The category (new sphere) or the sphere (new subsphere / service).
  final String? parentId;
  final String? parentName;
  final int suggestedPosition;

  /// A new service may hang under one of these instead of the sphere itself.
  final List<CatalogNode> subspheres;

  @override
  ConsumerState<CatalogEditDialog> createState() => _CatalogEditDialogState();
}

class _CatalogEditDialogState extends ConsumerState<CatalogEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameEn = TextEditingController(text: widget.node?.nameEn);
  late final _nameRu = TextEditingController(text: widget.node?.nameRu);
  late final _nameKk = TextEditingController(text: widget.node?.nameKk);
  late final _icon = TextEditingController(text: widget.node?.icon);
  late final _code = TextEditingController(text: widget.node?.code);
  late final _position = TextEditingController(text: '${widget.node?.sortOrder ?? widget.suggestedPosition}');
  String? _subsphereId;
  bool _codeEditedByHand = false;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEdit => widget.node != null;
  bool get _hasCode => widget.level != CatalogLevel.service;

  @override
  void dispose() {
    for (final controller in [_nameEn, _nameRu, _nameKk, _icon, _code, _position]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _title(AppLocalizations l10n) {
    final parent = widget.parentName ?? '';
    if (_isEdit) return l10n.catalogEditTitle(widget.node!.nameFor(Localizations.localeOf(context).languageCode));
    return switch (widget.level) {
      CatalogLevel.category => l10n.catalogNewCategory,
      CatalogLevel.sphere => l10n.catalogNewSphereIn(parent),
      CatalogLevel.subsphere => l10n.catalogNewSubsphereIn(parent),
      CatalogLevel.service => l10n.catalogNewServiceIn(parent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    String? required(String? value) => (value == null || value.trim().isEmpty) ? l10n.fieldRequired : null;
    const gap = SizedBox(height: FactorySpacing.space3);

    return FactoryDialog(
      title: _title(l10n),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _nameEn,
                  enabled: !_isSubmitting,
                  label: l10n.fieldNameEn,
                  textInputAction: TextInputAction.next,
                  validator: required,
                  onChanged: (value) {
                    if (!_isEdit && _hasCode && !_codeEditedByHand) _code.text = slugifyCode(value);
                  },
                ),
                gap,
                FactoryTextField(
                  controller: _nameRu,
                  enabled: !_isSubmitting,
                  label: l10n.fieldNameRu,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                gap,
                FactoryTextField(
                  controller: _nameKk,
                  enabled: !_isSubmitting,
                  label: l10n.fieldNameKk,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                if (widget.level == CatalogLevel.category) ...[
                  gap,
                  FactoryTextField(controller: _icon, enabled: !_isSubmitting, label: l10n.fieldIcon),
                ],
                if (!_isEdit && widget.level == CatalogLevel.service && widget.subspheres.isNotEmpty) ...[
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue: _subsphereId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.fieldSubsphereOptional),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.subsphereNone, overflow: TextOverflow.ellipsis)),
                      for (final subsphere in widget.subspheres)
                        DropdownMenuItem(value: subsphere.id, child: Text(subsphere.nameFor(languageCode))),
                    ],
                    onChanged: _isSubmitting ? null : (value) => setState(() => _subsphereId = value),
                  ),
                ],
                gap,
                FactoryTextField(
                  controller: _position,
                  enabled: !_isSubmitting,
                  label: l10n.fieldPosition,
                  keyboardType: TextInputType.number,
                  validator: (value) => int.tryParse(value?.trim() ?? '') == null ? l10n.fieldNumberInvalid : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space1),
                    child: Text(l10n.fieldPositionHelper, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
                if (_hasCode) ...[
                  gap,
                  FactoryTextField(
                    controller: _code,
                    enabled: !_isSubmitting && !_isEdit,
                    readOnly: _isEdit,
                    label: l10n.fieldCode,
                    onChanged: (_) => _codeEditedByHand = true,
                    validator: (value) {
                      if (_isEdit) return null;
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return l10n.fieldRequired;
                      return isValidCode(text) ? null : l10n.fieldCodeInvalid;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: FactorySpacing.space1),
                      child: Text(
                        _isEdit ? l10n.fieldCodeFixed : l10n.fieldCodeHelper,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: _isEdit ? l10n.save : l10n.create,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final api = ref.read(catalogApiProvider);
    final nameEn = _nameEn.text.trim();
    final nameRu = _nameRu.text.trim();
    final nameKk = _nameKk.text.trim();
    final icon = _icon.text.trim().isEmpty ? null : _icon.text.trim();
    final position = int.parse(_position.text.trim());
    try {
      if (_isEdit) {
        await api.update(widget.node!, nameKk: nameKk, nameRu: nameRu, nameEn: nameEn, icon: icon, sortOrder: position);
      } else {
        await api.create(
          widget.level,
          parentId: widget.parentId,
          code: _hasCode ? _code.text.trim() : null,
          nameKk: nameKk,
          nameRu: nameRu,
          nameEn: nameEn,
          icon: icon,
          sortOrder: position,
          subsphereId: _subsphereId,
        );
      }
      if (mounted) Navigator.of(context).pop(nameEn);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = isConflict(error) ? l10n.codeTaken : describeError(l10n, error);
        _isSubmitting = false;
      });
    }
  }
}

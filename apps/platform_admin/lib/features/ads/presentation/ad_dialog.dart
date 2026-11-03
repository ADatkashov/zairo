import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/media/pick_image.dart';
import '../../../core/network/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../cities/data/city.dart';
import '../../auth/data/auth_api.dart';
import '../../cities/data/city_api.dart';
import '../data/ad_api.dart';
import '../data/ad_banner.dart';

/// Create or edit a banner. New banners start as a draft unless "publish right
/// away" is on. Both links must be https (the backend refuses anything else; the
/// form says so before the round trip). The schedule is whole days: it starts at
/// the start day's midnight and runs through the end day. Pops with the title.
class AdDialog extends ConsumerStatefulWidget {
  const AdDialog({super.key, this.banner});

  /// Set when editing.
  final AdBanner? banner;

  @override
  ConsumerState<AdDialog> createState() => _AdDialogState();
}

/// True for a well-formed https URL.
bool isHttpsUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

class _AdDialogState extends ConsumerState<AdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.banner?.title);
  late final _subtitle = TextEditingController(text: widget.banner?.subtitle);
  late final _imageUrl = TextEditingController(text: widget.banner?.imageUrl);
  late final _videoUrl = TextEditingController(text: widget.banner?.videoUrl);
  late final _sortOrder = TextEditingController(text: '${widget.banner?.sortOrder ?? 0}');
  late String? _linkTarget = widget.banner?.linkTarget;
  late String? _cityCode = widget.banner?.cityCode;
  late DateTime _startDay = _dayOf(widget.banner?.startsAt.toLocal() ?? DateTime.now());
  // The last day it is live (the stored end is the next midnight).
  late DateTime _endDay = widget.banner != null
      ? _dayOf(widget.banner!.endsAt.toLocal().subtract(const Duration(minutes: 1)))
      : _dayOf(DateTime.now().add(const Duration(days: 7)));
  bool _publish = false;
  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _error;

  bool get _isEdit => widget.banner != null;

  /// Picks a picture on the device, uploads it and puts its link in the field: no hosting the image
  /// somewhere else first and pasting its address.
  Future<void> _uploadImage() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isUploading = true);
    try {
      final picked = await ref.read(pickImageProvider)();
      if (picked == null || !mounted) return;
      final url = await ref.read(authApiProvider).uploadImage(picked.bytes, picked.name);
      if (!mounted) return;
      setState(() => _imageUrl.text = url);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(l10n, error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  static DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  void dispose() {
    for (final controller in [_title, _subtitle, _imageUrl, _videoUrl, _sortOrder]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDay : _endDay,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => start ? _startDay = _dayOf(picked) : _endDay = _dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final date = DateFormat.yMMMd(locale.toString());
    final cities = ref.watch(citiesProvider).value ?? const <City>[];
    const gap = SizedBox(height: FactorySpacing.space3);
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;
    final datesInvalid = _endDay.isBefore(_startDay);

    return FactoryDialog(
      title: _isEdit ? l10n.adEditTitle(widget.banner!.title) : l10n.adNewTitle,
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _title,
                  enabled: !_isSubmitting,
                  label: l10n.adFieldTitle,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                gap,
                FactoryTextField(
                  controller: _subtitle,
                  enabled: !_isSubmitting,
                  label: l10n.adFieldSubtitle,
                  textInputAction: TextInputAction.next,
                ),
                gap,
                FactoryTextField(
                  controller: _imageUrl,
                  enabled: !_isSubmitting,
                  label: l10n.adFieldImageUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (v) => isHttpsUrl(v) ? null : l10n.adUrlInvalid,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FactoryButton(
                    label: l10n.adUploadImage,
                    icon: Icons.upload_rounded,
                    variant: FactoryButtonVariant.text,
                    isLoading: _isUploading,
                    onPressed: _isSubmitting || _isUploading ? null : _uploadImage,
                  ),
                ),
                gap,
                FactoryTextField(
                  controller: _videoUrl,
                  enabled: !_isSubmitting,
                  label: l10n.adFieldVideoUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty || isHttpsUrl(v)) ? null : l10n.adUrlInvalid,
                ),
                gap,
                // What customers will see on Home, live as the fields change.
                gap,
                ListenableBuilder(
                  listenable: Listenable.merge([_title, _subtitle, _imageUrl, _videoUrl]),
                  builder: (context, _) {
                    if (!isHttpsUrl(_imageUrl.text)) return const SizedBox.shrink();
                    final subtitle = _subtitle.text.trim();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.adPreviewLabel, style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: FactorySpacing.space2),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: FactoryBannerCard(
                            imageUrl: _imageUrl.text.trim(),
                            title: _title.text.trim().isEmpty ? l10n.adFieldTitle : _title.text.trim(),
                            subtitle: subtitle.isEmpty ? null : subtitle,
                            tag: widget.banner?.providerId != null ? l10n.adSponsored : null,
                            showPlay: isHttpsUrl(_videoUrl.text),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                gap,
                // Tapping a banner with a video plays it; this is where a banner WITHOUT one goes.
                DropdownButtonFormField<String?>(
                  initialValue: _linkTarget,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.adFieldLinkTarget),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l10n.adLinkNone)),
                    DropdownMenuItem<String?>(value: 'REWARDS', child: Text(l10n.adLinkRewards)),
                    DropdownMenuItem<String?>(value: 'SEARCH', child: Text(l10n.adLinkSearch)),
                  ],
                  onChanged: _isSubmitting ? null : (value) => setState(() => _linkTarget = value),
                ),
                gap,
                DropdownButtonFormField<String?>(
                  initialValue: cities.any((c) => c.code == _cityCode) ? _cityCode : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.adFieldCity),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l10n.adAllCities)),
                    for (final c in cities)
                      DropdownMenuItem<String?>(value: c.code, child: Text(c.nameFor(locale.languageCode))),
                  ],
                  onChanged: _isSubmitting ? null : (value) => setState(() => _cityCode = value),
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _pickDay(start: true),
                        child: Text('${l10n.adFieldStarts}: ${date.format(_startDay)}'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space2),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _pickDay(start: false),
                        child: Text('${l10n.adFieldEnds}: ${date.format(_endDay)}'),
                      ),
                    ),
                  ],
                ),
                if (datesInvalid)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: FactorySpacing.space1),
                      child: Text(
                        l10n.adDatesInvalid,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.error),
                      ),
                    ),
                  ),
                gap,
                FactoryTextField(
                  controller: _sortOrder,
                  enabled: !_isSubmitting,
                  label: l10n.adFieldSortOrder,
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v?.trim() ?? '') == null ? l10n.fieldNumberInvalid : null,
                ),
                if (!_isEdit)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.adFieldPublishNow),
                    value: _publish,
                    onChanged: _isSubmitting ? null : (value) => setState(() => _publish = value),
                  ),
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
          onPressed: _isSubmitting || datesInvalid ? null : _submit,
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
    final api = ref.read(adApiProvider);
    final subtitle = _subtitle.text.trim();
    final video = _videoUrl.text.trim();
    final startsAt = _startDay;
    // Through the end day: the stored end is the next local midnight.
    final endsAt = DateTime(_endDay.year, _endDay.month, _endDay.day + 1);
    try {
      if (_isEdit) {
        await api.update(
          widget.banner!.id,
          title: _title.text.trim(),
          subtitle: subtitle.isEmpty ? null : subtitle,
          imageUrl: _imageUrl.text.trim(),
          videoUrl: video.isEmpty ? null : video,
          linkTarget: _linkTarget,
          cityCode: _cityCode,
          startsAt: startsAt,
          endsAt: endsAt,
          sortOrder: int.parse(_sortOrder.text.trim()),
        );
      } else {
        await api.create(
          title: _title.text.trim(),
          subtitle: subtitle.isEmpty ? null : subtitle,
          imageUrl: _imageUrl.text.trim(),
          videoUrl: video.isEmpty ? null : video,
          linkTarget: _linkTarget,
          cityCode: _cityCode,
          startsAt: startsAt,
          endsAt: endsAt,
          sortOrder: int.parse(_sortOrder.text.trim()),
          publish: _publish,
        );
      }
      if (mounted) Navigator.of(context).pop(_title.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(AppLocalizations.of(context)!, error);
        _isSubmitting = false;
      });
    }
  }
}

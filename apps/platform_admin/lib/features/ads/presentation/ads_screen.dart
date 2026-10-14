import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../../cities/data/city.dart';
import '../../cities/data/city_api.dart';
import '../data/ad_api.dart';
import '../data/ad_banner.dart';
import 'ad_dialog.dart';

/// The banners shown on the customers' Home screen: create them, put them
/// live, pause or reject them. Reading is open to every platform role;
/// changing is for admins and moderators (see `canManageAds`).
class AdsScreen extends ConsumerWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canManage = ref.watch(permissionsProvider).canManageAds;
    final async = ref.watch(adBannersProvider);
    final cities = ref.watch(citiesProvider).value ?? const <City>[];
    Future<void> refresh() => ref.refresh(adBannersProvider.future);

    Future<void> create() async {
      final title = await showDialog<String>(context: context, builder: (_) => const AdDialog());
      if (title == null || !context.mounted) return;
      ref.invalidate(adBannersProvider);
      showSnack(context, l10n.adCreated(title));
    }

    return AreaScaffold(
      title: l10n.navAds,
      actions: [IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh)],
      floatingActionButton: canManage
          ? FloatingActionButton.extended(icon: const Icon(Icons.add), label: Text(l10n.adAdd), onPressed: create)
          : null,
      body: AsyncView<List<AdBanner>>(
        value: async,
        onRetry: () => ref.invalidate(adBannersProvider),
        builder: (banners) {
          if (banners.isEmpty) {
            return EmptyView(
              icon: Icons.campaign_outlined,
              title: l10n.adsEmptyTitle,
              message: canManage ? l10n.adsEmptyMessage : '',
              onRefresh: refresh,
            );
          }
          return ContentFrame(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  96,
                ),
                children: [
                  for (final banner in banners)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                      child: _BannerTile(banner: banner, cities: cities, canManage: canManage),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerTile extends ConsumerWidget {
  const _BannerTile({required this.banner, required this.cities, required this.canManage});

  final AdBanner banner;
  final List<City> cities;
  final bool canManage;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AdDialog(banner: banner),
    );
    if (title == null || !context.mounted) return;
    ref.invalidate(adBannersProvider);
    showSnack(context, AppLocalizations.of(context)!.adSaved(title));
  }

  Future<void> _move(BuildContext context, WidgetRef ref, String status, String Function(String title) message,
      {String? reason}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(adApiProvider).setStatus(banner.id, status, reason: reason);
      ref.invalidate(adBannersProvider);
      if (context.mounted) showSnack(context, message(banner.title));
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(title: banner.title),
    );
    if (reason == null || !context.mounted) return;
    await _move(context, ref, 'REJECTED', l10n.adRejectedMsg, reason: reason);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmAction(
      context,
      title: l10n.adDeleteTitle(banner.title),
      message: l10n.adDeleteMessage,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(adApiProvider).delete(banner.id);
      ref.invalidate(adBannersProvider);
      if (context.mounted) showSnack(context, l10n.adDeleted(banner.title));
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final date = DateFormat.yMMMd(locale.toString());
    final cityName = banner.cityCode == null
        ? l10n.adAllCities
        : (cities.where((c) => c.code == banner.cityCode).firstOrNull?.nameFor(languageCode) ?? banner.cityCode!);
    // endsAt is the exclusive end (the next midnight), so show the last day it is live.
    final lastDay = banner.endsAt.toLocal().subtract(const Duration(minutes: 1));
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary);

    return FactorySelectableTile(
      title: banner.title,
      onTap: canManage ? () => _edit(context, ref) : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.subtitle != null) Text(banner.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$cityName · ${date.format(banner.startsAt.toLocal())} – ${date.format(lastDay)}', style: small),
          if (banner.status == 'REJECTED' && banner.rejectionReason != null)
            Text(l10n.adRejectionReason(banner.rejectionReason!), style: small?.copyWith(color: colors.error)),
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space1),
            child: Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space1,
              children: [
                ToneBadge(label: adStatusLabel(l10n, banner.status), tone: adStatusTone(banner.status)),
                if (banner.hasVideo) ToneBadge(label: l10n.adHasVideo, icon: Icons.play_circle_outline_rounded),
                if (banner.providerId != null) ToneBadge(label: l10n.adSponsored),
              ],
            ),
          ),
        ],
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: l10n.moreActions,
              onSelected: (value) => switch (value) {
                'edit' => _edit(context, ref),
                'publish' => _move(context, ref, 'ACTIVE', l10n.adPublished),
                'pause' => _move(context, ref, 'PAUSED', l10n.adPausedMsg),
                'reject' => _reject(context, ref),
                _ => _delete(context, ref),
              },
              itemBuilder: (context) => [
                if (banner.canPublish) _item('publish', Icons.play_circle_outline_rounded, l10n.adActionPublish),
                if (banner.canPause) _item('pause', Icons.pause_circle_outline_rounded, l10n.adActionPause),
                if (banner.canReject) _item('reject', Icons.block_rounded, l10n.adActionReject),
                _item('edit', Icons.edit_outlined, l10n.edit),
                _item('delete', Icons.delete_outline, l10n.delete, color: colors.error),
              ],
            )
          : null,
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: value,
    child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: color), title: Text(label)),
  );
}

/// Asks why a banner is being rejected. Pops with the trimmed reason; the
/// backend refuses a rejection without one.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.title});

  final String title;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.adRejectTitle(widget.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.adRejectMessage),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _reason,
                label: l10n.adRejectReason,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.adRejectConfirm,
          variant: FactoryButtonVariant.danger,
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_reason.text.trim());
          },
        ),
      ],
    );
  }
}

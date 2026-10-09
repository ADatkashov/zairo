import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_redemption.dart';
import '../providers/loyalty_admin_providers.dart';
import '../widgets/loyalty_redemption_card.dart';

/// This business's redemption codes -- every status, newest first, paginated
/// like the customer roster. The "customer shows me a code at checkout"
/// flow lives behind the AppBar's apply action: a short code plus a
/// booking id, since the backend takes exactly that (`POST
/// .../redemptions/{code}/apply`) and nothing richer (no booking picker
/// endpoint exists on this surface -- see the final report's ambiguity
/// note).
class LoyaltyRedemptionsScreen extends ConsumerStatefulWidget {
  final String providerId;

  const LoyaltyRedemptionsScreen({super.key, required this.providerId});

  @override
  ConsumerState<LoyaltyRedemptionsScreen> createState() => _LoyaltyRedemptionsScreenState();
}

class _LoyaltyRedemptionsScreenState extends ConsumerState<LoyaltyRedemptionsScreen> {
  int _page = 0;
  final List<LoyaltyRedemption> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;

  void _resetPaging() {
    _page = 0;
    _items.clear();
    _loadedPages.clear();
    _totalPages = 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (widget.providerId, _page);
    final pageAsync = ref.watch(loyaltyRedemptionsProvider(key));

    ref.listen(loyaltyRedemptionsProvider(key), (previous, next) {
      next.whenData((resp) {
        if (_loadedPages.add(resp.number)) {
          setState(() {
            _items.addAll(resp.content);
            _totalPages = resp.totalPages;
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openApplyDialog(context),
        icon: const Icon(Icons.qr_code_2_outlined),
        label: Text(l10n.loyaltyRedemptionApplyButton),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(loyaltyRedemptionsProvider);
          setState(_resetPaging);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FactorySpacing.space4,
            FactorySpacing.space4,
            FactorySpacing.space4,
            FactorySpacing.space8 + FactorySpacing.space6,
          ),
          children: [
            if (_items.isEmpty)
              pageAsync.when(
                data: (resp) => resp.content.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                        child: Center(
                          child: Text(
                            l10n.loyaltyRedemptionsEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                          ),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                        child: FactoryLoadingState(),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                  child: FactoryLoadingState(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
                  child: FactoryErrorState(
                    message: l10n.errorLoyaltyRedemptionsLoadFailed,
                    onRetry: () => ref.invalidate(loyaltyRedemptionsProvider(key)),
                  ),
                ),
              )
            else ...[
              for (final redemption in _items) ...[
                LoyaltyRedemptionCard(
                  redemption: redemption,
                  locale: Localizations.localeOf(context).toString(),
                  onCancel: redemption.status == LoyaltyRedemptionStatus.active
                      ? () => _cancel(context, redemption)
                      : null,
                ),
                const SizedBox(height: FactorySpacing.space3),
              ],
              if (_page + 1 < _totalPages)
                Center(
                  child: pageAsync.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(FactorySpacing.space4),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : FactoryButton(
                          label: l10n.loyaltyCustomersLoadMore,
                          variant: FactoryButtonVariant.secondary,
                          onPressed: () => setState(() => _page += 1),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openApplyDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ApplyRedemptionDialog(providerId: widget.providerId),
    );
    if (result == true) {
      invalidateLoyaltyRedemptionData(ref, widget.providerId);
      setState(_resetPaging);
    }
  }

  Future<void> _cancel(BuildContext context, LoyaltyRedemption redemption) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.loyaltyRedemptionCancelConfirmTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.loyaltyRedemptionCancelConfirmMessage(redemption.code)),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: reasonController,
            label: '${l10n.loyaltyRedemptionCancelReasonLabel} (${l10n.loyaltySettingsOptionalSuffix})',
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.cancelButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.loyaltyRedemptionCancelButton,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      final reason = reasonController.text.trim();
      await ref
          .read(loyaltyAdminApiProvider)
          .cancelRedemption(widget.providerId, redemption.id, reason: reason.isEmpty ? null : reason);
      invalidateLoyaltyRedemptionData(ref, widget.providerId);
      setState(_resetPaging);
    } catch (e) {
      if (!context.mounted) return;
      final message = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _ApplyRedemptionDialog extends ConsumerStatefulWidget {
  final String providerId;

  const _ApplyRedemptionDialog({required this.providerId});

  @override
  ConsumerState<_ApplyRedemptionDialog> createState() => _ApplyRedemptionDialogState();
}

class _ApplyRedemptionDialogState extends ConsumerState<_ApplyRedemptionDialog> {
  final _codeController = TextEditingController();
  final _bookingIdController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _bookingIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.loyaltyRedemptionApplyDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.loyaltyRedemptionApplyDialogSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _codeController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyRedemptionCodeLabel,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _bookingIdController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyRedemptionBookingIdLabel,
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
          label: l10n.loyaltyRedemptionApplyButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    final bookingId = _bookingIdController.text.trim();
    if (code.isEmpty || bookingId.isEmpty) {
      setState(() => _error = l10n.loyaltyRedemptionApplyValidationError);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).applyRedemption(widget.providerId, code, bookingId: bookingId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed;
        _isSubmitting = false;
      });
    }
  }
}

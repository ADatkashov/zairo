import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/chat_message.dart';
import '../providers/message_seen_provider.dart';
import '../providers/messaging_providers.dart';

/// One conversation's full thread, from the business owner's side --
/// plain REST polling only, no WebSocket/read-receipts (see backend/
/// messaging's package-info.java: deliberately out of scope). A ~9s
/// refresh timer while this screen is mounted, plus pull-to-refresh, is
/// the full extent of "live-ness" this MVP offers.
///
/// [customerDisplayName] only backs the AppBar title -- [BusinessInboxScreen]
/// already resolved it (falling back to
/// [AppLocalizations.messagingUnknownCustomer]) before pushing here, so
/// this screen never needs to know about the null case itself.
class BusinessChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String customerDisplayName;

  const BusinessChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.customerDisplayName,
  });

  @override
  ConsumerState<BusinessChatThreadScreen> createState() => _BusinessChatThreadScreenState();
}

class _BusinessChatThreadScreenState extends ConsumerState<BusinessChatThreadScreen> {
  static const _refreshInterval = Duration(seconds: 9);

  final _composeController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isSending = false;
  int _lastMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      ref.invalidate(conversationThreadProvider(widget.conversationId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _composeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _composeController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref.read(messagingApiProvider).reply(widget.conversationId, text);
      _composeController.clear();
      ref.invalidate(conversationThreadProvider(widget.conversationId));
      if (!mounted) return;
      setState(() => _isSending = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorMessageSendFailed)));
    }
  }

  void _markSeen(DateTime at) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(messageSeenProvider.notifier).markSeen(widget.conversationId, at);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final currentUserId = ref.watch(authControllerProvider).value?.id;
    final threadAsync = ref.watch(conversationThreadProvider(widget.conversationId));

    // Fires on every load (initial fetch, the periodic refresh timer, a
    // pull-to-refresh, or right after this screen's own reply) --
    // auto-scrolling to the bottom whenever the message count actually
    // changed covers "on load" and "on send" from the spec in one place,
    // without a separate flag for "I just sent something".
    ref.listen(conversationThreadProvider(widget.conversationId), (previous, next) {
      next.whenData((messages) {
        if (messages.length != _lastMessageCount) {
          _lastMessageCount = messages.length;
          _scrollToBottomNextFrame();
        }
      });
    });

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: widget.customerDisplayName),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(conversationThreadProvider(widget.conversationId)),
              child: threadAsync.when(
                data: (messages) {
                  // What is on screen counts as read.
                  if (messages.isNotEmpty) _markSeen(messages.last.createdAt);
                  if (messages.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(FactorySpacing.space4),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                          child: Center(
                            child: Text(
                              l10n.chatEmptyThread,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isOwn = currentUserId != null && message.senderUserId == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                        child: _MessageBubble(message: message, isOwn: isOwn),
                      );
                    },
                  );
                },
                loading: () => const FactoryLoadingState(),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    child: FactoryErrorState(
                      message: l10n.errorMessagesLoadFailed,
                      onRetry: () => ref.invalidate(conversationThreadProvider(widget.conversationId)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ComposeBar(
            controller: _composeController,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ComposeBar({required this.controller, required this.isSending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          FactorySpacing.space4,
          FactorySpacing.space2,
          FactorySpacing.space4,
          FactorySpacing.space3,
        ),
        decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: FactoryTextField(
                label: l10n.chatComposeHint,
                controller: controller,
                enabled: !isSending,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              tooltip: l10n.chatSendButtonTooltip,
              icon: isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final bg = isOwn ? colors.primary : colors.surfaceAlt;
    final fg = isOwn ? colors.onPrimary : colors.text;

    return Row(
      mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3, vertical: FactorySpacing.space2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isOwn ? 14 : 2),
                bottomRight: Radius.circular(isOwn ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // A non-interactive marker only -- there's no cross-app
                // booking lookup available here, so this never navigates
                // anywhere (see ChatMessage.bookingId's doc comment).
                if (message.bookingId != null) ...[
                  FactoryBadge(
                    label: l10n.chatBookingChipLabel,
                    icon: Icons.event_outlined,
                    backgroundColor: (isOwn ? colors.onPrimary : colors.primary).withValues(alpha: 0.14),
                    foregroundColor: isOwn ? colors.onPrimary : colors.primary,
                  ),
                  const SizedBox(height: FactorySpacing.space1),
                ],
                Text(message.body, style: textTheme.bodyMedium?.copyWith(color: fg)),
                const SizedBox(height: 2),
                Text(
                  DateFormat.Hm(locale).format(message.createdAt.toLocal()),
                  style: textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

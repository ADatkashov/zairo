import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/chat_message.dart';
import '../providers/message_seen_provider.dart';
import '../providers/messaging_providers.dart';

/// A 1:1 thread between the current customer and one provider. Keyed by
/// [providerId] rather than a conversationId — the customer app has no
/// client-side conversationId to key off of before a thread's first
/// message is sent (unlike the business side, which already knows its own
/// conversations), and every customer-facing messaging endpoint is rooted
/// at providerId (`GET/POST /providers/{id}/messages`) regardless.
///
/// No WebSocket/read-receipts/unread counts — deliberately out of scope
/// for this pass (see backend/messaging's package-info.java and
/// docs/PRODUCT_PRODUCTION_ROADMAP.md section 14). The only "live-ness" is
/// this periodic poll plus pull-to-refresh.
class ChatThreadScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;

  const ChatThreadScreen({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isSending = false;
  int _lastMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      ref.invalidate(threadWithProviderProvider(widget.providerId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markSeen(DateTime at) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(messageSeenProvider.notifier).markSeen(widget.providerId, at);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final messagesAsync = ref.watch(threadWithProviderProvider(widget.providerId));
    final currentUserId = ref.watch(authControllerProvider).value?.id;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: widget.providerName),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  // Scrolls to bottom on the very first load and whenever a
                  // fresh message (ours or the poll's) arrives — not on
                  // every rebuild, so the user isn't yanked back down while
                  // reading scrollback between polls.
                  if (messages.length != _lastMessageCount) {
                    _lastMessageCount = messages.length;
                    _scrollToBottom();
                  }
                  // What is on screen counts as read: the thread shows up to
                  // its newest message, so the "new messages" count drops.
                  if (messages.isNotEmpty) _markSeen(messages.last.createdAt);

                  if (messages.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => ref.refresh(
                        threadWithProviderProvider(widget.providerId).future,
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: FactoryEmptyState(
                                icon: Symbols.forum_rounded,
                                title: l10n.chatThreadEmptyTitle,
                                message: l10n.chatThreadEmptyMessage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(
                      threadWithProviderProvider(widget.providerId).future,
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(FactorySpacing.space4),
                      itemCount: messages.length,
                      itemBuilder: (context, index) => _MessageBubble(
                        message: messages[index],
                        isMine: messages[index].senderUserId == currentUserId,
                      ),
                    ),
                  );
                },
                loading: () => const FactoryLoadingState(),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    child: FactoryErrorState(
                      message: l10n.errorChatThreadLoadFailed,
                      onRetry: () => ref.invalidate(
                        threadWithProviderProvider(widget.providerId),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _ComposeBar(
              controller: _bodyController,
              isSending: _isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _bodyController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(messagingApiProvider)
          .sendToProvider(widget.providerId, text);
      _bodyController.clear();
      ref.invalidate(threadWithProviderProvider(widget.providerId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorChatSendFailed(e.toString()))));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (message.bookingId != null) ...[
            FactoryChip(
              icon: Symbols.calendar_month_rounded,
              label: l10n.chatBookingContextLabel,
            ),
            const SizedBox(height: FactorySpacing.space1),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: FactorySpacing.space3,
              vertical: FactorySpacing.space2,
            ),
            decoration: BoxDecoration(
              color: isMine ? colors.primary : colors.surfaceAlt,
              borderRadius: FactoryRadius.lgRadius,
            ),
            child: Text(
              message.body,
              style: textTheme.bodyMedium?.copyWith(
                color: isMine ? colors.onPrimary : colors.text,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatMonthDayTime(l10n, message.createdAt.toLocal()),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
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

  const _ComposeBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Container(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: FactoryTextField(
              label: l10n.chatComposeLabel,
              controller: controller,
              enabled: !isSending,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: FactorySpacing.space2),
          IconButton.filled(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : const Icon(Symbols.send_rounded),
          ),
        ],
      ),
    );
  }
}

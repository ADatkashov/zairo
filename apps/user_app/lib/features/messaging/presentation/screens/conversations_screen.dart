import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/initials.dart';
import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/logged_out_gate.dart';
import '../../data/models/conversation.dart';
import '../providers/message_seen_provider.dart';
import '../providers/messaging_providers.dart';

/// The customer's inbox — one row per provider they've ever messaged.
/// Pushed from Profile's "Messages" tile, same as Favorites, not its own
/// bottom-nav tab (see app_router.dart's doc comment on the 4-tab set).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.messagesTitle),
      body: authState.when(
        data: (user) => user == null
            ? LoggedOutGate(
                icon: Symbols.forum_rounded,
                message: l10n.conversationsLoggedOutPrompt,
              )
            : const _ConversationsList(),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationsList extends ConsumerWidget {
  const _ConversationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(myInboxProvider);

    return conversationsAsync.when(
      data: (conversations) {
        Future<void> refresh() => ref.refresh(myInboxProvider.future);

        if (conversations.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: FactoryEmptyState(
                      icon: Symbols.forum_rounded,
                      title: l10n.conversationsEmptyTitle,
                      message: l10n.conversationsEmptyMessage,
                      actionLabel: l10n.conversationsFindBusinessButton,
                      onAction: () => context.go(AppRoutes.search()),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: conversations.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) =>
                _ConversationTile(conversation: conversations[index]),
          ),
        );
      },
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorConversationsLoadFailed,
            onRetry: () => ref.invalidate(myInboxProvider),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew =
        ref.watch(messageSeenProvider).value?.isNew(conversation.providerId, conversation.lastMessageAt) ?? false;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final providerName = conversation.providerName ?? l10n.messagingUnknownBusinessName;

    return FactoryCard(
      onTap: () => context.push(
        AppRoutes.chat(conversation.providerId, providerName: providerName),
      ),
      child: Row(
        children: [
          FactoryAvatar(initials: initialsFor(providerName)),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: isNew ? FontWeight.w800 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMonthDayTime(l10n, conversation.lastMessageAt.toLocal()),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          if (isNew) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colors.coral, shape: BoxShape.circle),
            ),
            const SizedBox(width: FactorySpacing.space2),
          ],
          Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
        ],
      ),
    );
  }
}

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/no_business_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/models/conversation.dart';
import '../providers/message_seen_provider.dart';
import '../providers/messaging_providers.dart';
import 'business_chat_thread_screen.dart';

/// The business owner's inbox -- one conversation per customer who has
/// ever messaged one of this owner's businesses, most recently active
/// first (see backend/messaging's package-info.java: plain REST polling,
/// no WebSocket/read-receipts by design). Same provider-resolution shape
/// as [CampaignCenterScreen]: the messaging API is scoped to one provider
/// at a time, so an owner with more than one business picks which one via
/// a chip row; an owner with exactly one skips straight to its inbox.
class BusinessInboxScreen extends ConsumerStatefulWidget {
  final String ownerUserId;

  const BusinessInboxScreen({super.key, required this.ownerUserId});

  @override
  ConsumerState<BusinessInboxScreen> createState() =>
      _BusinessInboxScreenState();
}

class _BusinessInboxScreenState extends ConsumerState<BusinessInboxScreen> {
  String? _providerId;

  void _selectProvider(String providerId) {
    if (providerId == _providerId) return;
    setState(() => _providerId = providerId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final providersAsync = ref.watch(myProvidersProvider(widget.ownerUserId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.businessInboxScreenTitle),
      body: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return NoBusinessState(message: l10n.businessInboxNoBusinesses);
          }
          if (_providerId == null ||
              !providers.any((p) => p.id == _providerId)) {
            _providerId = providers.first.id;
          }
          return _BusinessInboxBody(
            providerId: _providerId!,
            providers: providers,
            onSelectProvider: _selectProvider,
          );
        },
        loading: () => const FactoryLoadingState(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorBusinessesLoadFailed,
              onRetry: () =>
                  ref.invalidate(myProvidersProvider(widget.ownerUserId)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessInboxBody extends ConsumerWidget {
  final String providerId;
  final List<AdminProvider> providers;
  final ValueChanged<String> onSelectProvider;

  const _BusinessInboxBody({
    required this.providerId,
    required this.providers,
    required this.onSelectProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final inboxAsync = ref.watch(providerInboxProvider(providerId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(providerInboxProvider(providerId)),
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          Text(
            l10n.businessInboxSubtitle,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: FactorySpacing.space4),
          if (providers.length > 1) ...[
            _ProviderPicker(
              providers: providers,
              selectedId: providerId,
              onSelect: onSelectProvider,
            ),
            const SizedBox(height: FactorySpacing.space4),
          ],
          inboxAsync.when(
            data: (conversations) => conversations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FactorySpacing.space6,
                    ),
                    child: Center(
                      child: FactoryEmptyState(
                        icon: Icons.forum_outlined,
                        title: l10n.businessInboxEmpty,
                        message: '',
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final conversation in conversations) ...[
                        _ConversationCard(
                          conversation: conversation,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BusinessChatThreadScreen(
                                conversationId: conversation.id,
                                customerDisplayName:
                                    conversation.customerDisplayName ??
                                    l10n.messagingUnknownCustomer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: FactorySpacing.space3),
                      ],
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
              child: FactoryLoadingState(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: FactorySpacing.space4,
              ),
              child: FactoryErrorState(
                message: l10n.errorConversationsLoadFailed,
                onRetry: () =>
                    ref.invalidate(providerInboxProvider(providerId)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  final List<AdminProvider> providers;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _ProviderPicker({
    required this.providers,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in providers)
          FactoryChip(
            label: provider.name,
            selected: provider.id == selectedId,
            onTap: () => onSelect(provider.id),
          ),
      ],
    );
  }
}

class _ConversationCard extends ConsumerWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationCard({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew =
        ref
            .watch(messageSeenProvider)
            .value
            ?.isNew(conversation.id, conversation.lastMessageAt) ??
        false;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final name =
        conversation.customerDisplayName ?? l10n.messagingUnknownCustomer;

    return FactoryCard(
      onTap: onTap,
      child: Row(
        children: [
          FactoryAvatar(initials: _initialsFor(name), size: 40),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: isNew ? FontWeight.w800 : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd(locale)
                      .add_Hm()
                      .format(conversation.lastMessageAt.toLocal()),
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (isNew) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
          ],
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

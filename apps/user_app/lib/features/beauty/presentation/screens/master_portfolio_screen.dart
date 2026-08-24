import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/beauty_providers.dart';
import 'portfolio_fullscreen_viewer.dart';

class MasterPortfolioScreen extends ConsumerWidget {
  final String masterId;
  final String masterName;

  const MasterPortfolioScreen({super.key, required this.masterId, required this.masterName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final portfolioAsync = ref.watch(masterPortfolioProvider(masterId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.masterPortfolioTitle(masterName))),
      body: portfolioAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: FactoryEmptyState(
                icon: Icons.photo_library_outlined,
                title: l10n.portfolioEmptyTitle,
                message: l10n.portfolioEmptyMessage,
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PortfolioFullscreenViewer(items: items, initialIndex: index),
                    fullscreenDialog: true,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                    if (item.caption != null) ...[
                      const SizedBox(height: 4),
                      Text(item.caption!, style: Theme.of(context).textTheme.bodySmall, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FactoryErrorState(
            message: l10n.errorPortfolioLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(masterPortfolioProvider(masterId)),
          ),
        ),
      ),
    );
  }
}

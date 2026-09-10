import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/beauty_providers.dart';
import 'portfolio_fullscreen_viewer.dart';

class MasterPortfolioScreen extends ConsumerWidget {
  final String masterId;
  final String masterName;

  const MasterPortfolioScreen({
    super.key,
    required this.masterId,
    required this.masterName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final portfolioAsync = ref.watch(masterPortfolioProvider(masterId));

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.masterPortfolioTitle(masterName)),
      body: portfolioAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: FactoryEmptyState(
                icon: Symbols.photo_library_rounded,
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
              return Semantics(
                button: true,
                container: true,
                // excludeSemantics: true hides the descendant caption
                // Text's own auto-generated semantics node — without it,
                // that node merges into this one alongside the explicit
                // label below, so a screen reader would announce the
                // caption twice (once as this tile's label, once as the
                // merged-in Text child) instead of once.
                excludeSemantics: true,
                label: item.caption ?? l10n.portfolioPhotoSemanticLabel,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PortfolioFullscreenViewer(
                        items: items,
                        initialIndex: index,
                      ),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(
                                    Symbols.broken_image_rounded,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      if (item.caption != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.caption!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const FactoryLoadingState(),
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

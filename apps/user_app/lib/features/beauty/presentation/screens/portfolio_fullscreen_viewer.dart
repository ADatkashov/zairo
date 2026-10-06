import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/portfolio_item.dart';

/// Fullscreen swipeable viewer over the same portfolio items already shown
/// in the grid — reuses their existing imageUrl (backed by the storage
/// module's upload API, see MasterPortfolioScreen) rather than fetching
/// anything new.
class PortfolioFullscreenViewer extends StatefulWidget {
  final List<PortfolioItem> items;
  final int initialIndex;

  const PortfolioFullscreenViewer({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<PortfolioFullscreenViewer> createState() =>
      _PortfolioFullscreenViewerState();
}

class _PortfolioFullscreenViewerState extends State<PortfolioFullscreenViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // Swipe the photo up or down to close it, the way every photo viewer
        // does; the x button stays for anyone who doesn't know the gesture.
        child: Dismissible(
          key: const ValueKey('portfolio-viewer-dismiss'),
          direction: DismissDirection.vertical,
          onDismissed: (_) => Navigator.of(context).pop(),
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _PortfolioPage(item: widget.items[i], l10n: l10n),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Symbols.close_rounded, color: Colors.white),
                  tooltip: l10n.portfolioViewerCloseTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              if (widget.items.length > 1)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Text(
                    l10n.portfolioViewerCounter(
                      _index + 1,
                      widget.items.length,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (widget.items.length > 1) ...[
                if (_index > 0)
                  Positioned(
                    left: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Symbols.chevron_left_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        tooltip: l10n.portfolioViewerPreviousTooltip,
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  ),
                if (_index < widget.items.length - 1)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Symbols.chevron_right_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        tooltip: l10n.portfolioViewerNextTooltip,
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  ),
              ],
              if (item.caption != null && item.caption!.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    item.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioPage extends StatelessWidget {
  final PortfolioItem item;
  final AppLocalizations l10n;

  const _PortfolioPage({required this.item, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      child: Center(
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.broken_image_rounded,
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.errorPortfolioImageLoadFailed,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

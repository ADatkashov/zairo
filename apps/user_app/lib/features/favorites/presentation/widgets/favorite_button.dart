import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../providers/favorites_providers.dart';

/// A heart toggle. Not logged in yet? Tapping it opens LoginScreen instead
/// of silently failing — same gate pattern as ProviderDetailScreen's Book
/// button.
class FavoriteButton extends ConsumerStatefulWidget {
  final String providerId;

  const FavoriteButton({super.key, required this.providerId});

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).value;

    if (currentUser == null) {
      return IconButton(
        icon: const Icon(Icons.favorite_border),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
    }

    final key = (userId: currentUser.id, providerId: widget.providerId);
    final favoritedAsync = ref.watch(isFavoritedProvider(key));

    return favoritedAsync.when(
      data: (isFavorited) => IconButton(
        icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border),
        color: isFavorited ? Colors.red : null,
        onPressed: _isToggling ? null : () => _toggle(currentUser.id, isFavorited),
      ),
      loading: () => const IconButton(icon: Icon(Icons.favorite_border), onPressed: null),
      error: (error, stackTrace) => const IconButton(icon: Icon(Icons.favorite_border), onPressed: null),
    );
  }

  Future<void> _toggle(String userId, bool currentlyFavorited) async {
    setState(() => _isToggling = true);
    final api = ref.read(favoritesApiProvider);
    if (currentlyFavorited) {
      await api.removeFavorite(userId, widget.providerId);
    } else {
      await api.addFavorite(userId, widget.providerId);
    }
    ref.invalidate(isFavoritedProvider((userId: userId, providerId: widget.providerId)));
    ref.invalidate(myFavoritesProvider(userId));
    if (mounted) setState(() => _isToggling = false);
  }
}

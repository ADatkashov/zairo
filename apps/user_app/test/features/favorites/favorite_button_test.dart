import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/favorites/data/favorites_api.dart';
import 'package:zairo/features/favorites/presentation/providers/favorites_providers.dart';
import 'package:zairo/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeFavoritesApi extends FavoritesApi {
  _FakeFavoritesApi({bool initiallyFavorited = false})
    : _favorited = initiallyFavorited,
      super(DioClient(Dio()));

  bool _favorited;
  int addCalls = 0;
  int removeCalls = 0;

  @override
  Future<bool> isFavorited(String userId, String providerId) async =>
      _favorited;

  @override
  Future<void> addFavorite(String userId, String providerId) async {
    addCalls++;
    _favorited = true;
  }

  @override
  Future<void> removeFavorite(String userId, String providerId) async {
    removeCalls++;
    _favorited = false;
  }
}

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(
      id: 'user-1',
      email: 'a@example.com',
      displayName: 'A',
      role: 'CUSTOMER',
    );
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

void main() {
  testWidgets('shows an outline heart and a login gate when logged out', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesApiProvider.overrideWithValue(_FakeFavoritesApi()),
          authControllerProvider.overrideWith(_LoggedOutAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FavoriteButton(providerId: 'provider-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.favorite_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
      isNot(1),
    );

    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets(
    'shows a filled heart when already favorited and toggles it off',
    (tester) async {
      final fakeApi = _FakeFavoritesApi(initiallyFavorited: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesApiProvider.overrideWithValue(fakeApi),
            authControllerProvider.overrideWith(_LoggedInAuthController.new),
          ],
          child: MaterialApp(
            theme: factoryLightTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: FavoriteButton(providerId: 'provider-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
        1,
      );
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.favorite_rounded));
      await tester.pumpAndSettle();

      expect(fakeApi.removeCalls, 1);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
        0,
      );
    },
  );

  testWidgets('toggles an unfavorited provider on', (tester) async {
    final fakeApi = _FakeFavoritesApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesApiProvider.overrideWithValue(fakeApi),
          authControllerProvider.overrideWith(_LoggedInAuthController.new),
        ],
        child: MaterialApp(
          theme: factoryLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FavoriteButton(providerId: 'provider-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.favorite_rounded));
    await tester.pumpAndSettle();

    expect(fakeApi.addCalls, 1);
    expect(tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill, 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/booking/presentation/screens/provider_detail_screen.dart';
import '../../features/city/presentation/screens/city_selection_screen.dart';
import '../../features/discovery/data/models/provider_search_result.dart';
import '../../features/discovery/presentation/screens/home_screen.dart';
import '../../features/discovery/presentation/screens/search_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/loyalty/presentation/screens/business_loyalty_screen.dart';
import '../../features/loyalty/presentation/screens/my_redemptions_screen.dart';
import '../../features/loyalty/presentation/screens/my_rewards_screen.dart';
import '../../features/main_wrapper/presentation/screens/main_wrapper.dart';
import '../../features/messaging/presentation/screens/chat_thread_screen.dart';
import '../../features/messaging/presentation/screens/conversations_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/about_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/support_screen.dart';
import '../../features/settings/presentation/screens/security_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../l10n/app_localizations.dart';
import 'app_routes.dart';
import '../widgets/scroll_to_top_on_tab_reselect.dart';
import 'route_screens.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final homeNavigatorKey = GlobalKey<NavigatorState>();
final searchNavigatorKey = GlobalKey<NavigatorState>();
final bookingsNavigatorKey = GlobalKey<NavigatorState>();
final profileNavigatorKey = GlobalKey<NavigatorState>();

/// Tab set is Home/Search/Bookings/Profile — 4, not the original Factory
/// Design System v0.2 artifact's 5 (Home/Search/Bookings/Favorites/
/// Profile). Favorites earned its own tab in that spec but turned out to
/// be reached far less often than the other four; it's now a normal push
/// from Profile (see ProfileScreen's favorites stat tile) instead of
/// permanent bottom-nav real estate, with the ♥ on every provider card
/// (see FavoriteButton) covering the actual "save this" moment. Settings
/// is the same story — reachable from Profile's AppBar action, never its
/// own tab.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: AppRoutes.citySelection,
        builder: (context, state) => const CitySelectionScreen(),
      ),
      GoRoute(
        path: '/provider/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ProviderSearchResult) {
            return ProviderDetailScreen(provider: extra);
          }
          return ProviderDetailRoute(providerId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ConversationsScreen(),
        routes: [
          GoRoute(
            path: ':providerId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ChatThreadScreen(
              providerId: state.pathParameters['providerId']!,
              providerName:
                  state.uri.queryParameters['name'] ??
                  AppLocalizations.of(context)!.messagingUnknownBusinessName,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/loyalty/:providerId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => BusinessLoyaltyScreen(
          providerId: state.pathParameters['providerId']!,
          providerName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: AppRoutes.rewards,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyRewardsScreen(),
      ),
      GoRoute(
        path: AppRoutes.redemptions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyRedemptionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const VehiclesRoute(),
      ),
      GoRoute(
        path: AppRoutes.support,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'security',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const SecuritySettingsScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainWrapper(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ScrollToTopOnTabReselect(
                  tabIndex: 0,
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: searchNavigatorKey,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => ScrollToTopOnTabReselect(
                  tabIndex: 1,
                  child: SearchScreen(
                    initialVertical: state.uri.queryParameters['category'],
                    initialQuery: state.uri.queryParameters['q'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: bookingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const ScrollToTopOnTabReselect(
                  tabIndex: 2,
                  child: MyBookingsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ScrollToTopOnTabReselect(
                  tabIndex: 3,
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

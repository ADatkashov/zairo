import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/city/presentation/screens/city_selection_screen.dart';
import '../../features/discovery/presentation/screens/home_screen.dart';
import '../../features/discovery/presentation/screens/search_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/main_wrapper/presentation/screens/main_wrapper.dart';

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
        path: '/city-selection',
        builder: (context, state) => const CitySelectionScreen(),
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
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: searchNavigatorKey,
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: bookingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/bookings',
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

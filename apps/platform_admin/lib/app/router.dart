import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/presentation/activity_screen.dart';
import '../features/auth/data/platform_session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/businesses/presentation/businesses_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/cities/presentation/cities_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/finance/presentation/finance_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/staff/presentation/staff_screen.dart';
import 'more_screen.dart';
import 'routes.dart';
import 'shell.dart';

/// Where the router starts — the dashboard, except in tests that open a deep
/// link.
final initialLocationProvider = Provider<String>((ref) => ConsoleRoutes.dashboard);

final routerProvider = Provider<GoRouter>((ref) {
  // go_router re-runs `redirect` whenever this notifies — i.e. whenever the
  // session appears, expires or the role changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = buildRouter(
    refreshListenable: refresh,
    sessionOf: () => ref.read(sessionControllerProvider),
    initialLocation: ref.read(initialLocationProvider),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Where a signed-out person lands after signing in: the page they were
/// trying to open (carried in `from`), or the dashboard.
String _afterLogin(GoRouterState state) {
  final from = state.uri.queryParameters['from'];
  if (from != null &&
      from.startsWith('/') &&
      !from.startsWith(ConsoleRoutes.login) &&
      !from.startsWith(ConsoleRoutes.splash)) {
    return from;
  }
  return ConsoleRoutes.dashboard;
}

GoRouter buildRouter({
  required Listenable refreshListenable,
  required AsyncValue<PlatformSession?> Function() sessionOf,
  String initialLocation = ConsoleRoutes.dashboard,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = sessionOf();
      final location = state.uri.path;

      // Still checking whether the stored token is good. The page that was
      // asked for rides along in `from`, so a browser refresh on /catalog
      // lands back on /catalog instead of the dashboard.
      if (session.isLoading) {
        if (location == ConsoleRoutes.splash) return null;
        return location == '/'
            ? ConsoleRoutes.splash
            : '${ConsoleRoutes.splash}?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      final signedIn = session.value != null;
      if (!signedIn) {
        if (location == ConsoleRoutes.login) return null;
        final from = location == ConsoleRoutes.splash
            ? state.uri.queryParameters['from']
            : location == '/'
            ? null
            : state.uri.toString();
        return from == null ? ConsoleRoutes.login : '${ConsoleRoutes.login}?from=${Uri.encodeComponent(from)}';
      }

      if (location == ConsoleRoutes.login || location == ConsoleRoutes.splash || location == '/') {
        return _afterLogin(state);
      }
      // Staff accounts are for platform admins; anyone else is sent home.
      if (location == ConsoleRoutes.staff && !session.requireValue!.permissions.canManageStaff) {
        return ConsoleRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: ConsoleRoutes.splash, builder: (context, state) => const _Splash()),
      GoRoute(path: ConsoleRoutes.login, builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ConsoleShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ConsoleRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
                routes: [GoRoute(path: 'reports', builder: (context, state) => const ReportsScreen())],
              ),
            ],
          ),
          _branch(
            ConsoleRoutes.businesses,
            (state) => BusinessesScreen(initialStatus: state.uri.queryParameters['status']),
          ),
          _branch(ConsoleRoutes.catalog, (state) => const CatalogScreen()),
          _branch(ConsoleRoutes.cities, (state) => const CitiesScreen()),
          _branch(ConsoleRoutes.finance, (state) => FinanceScreen(initialTab: state.uri.queryParameters['tab'])),
          _branch(ConsoleRoutes.activity, (state) => const ActivityScreen()),
          _branch(ConsoleRoutes.staff, (state) => const StaffScreen()),
          _branch(ConsoleRoutes.settings, (state) => const SettingsScreen()),
          _branch(ConsoleRoutes.more, (state) => const MoreScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _GoHome(),
  );
}

StatefulShellBranch _branch(String path, Widget Function(GoRouterState state) builder) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => builder(state))],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Unknown URL: quietly go to the dashboard.
class _GoHome extends StatefulWidget {
  const _GoHome();

  @override
  State<_GoHome> createState() => _GoHomeState();
}

class _GoHomeState extends State<_GoHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(ConsoleRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

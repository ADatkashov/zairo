import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/automation/presentation/screens/automation_center_screen.dart';
import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/campaigns/presentation/screens/campaign_center_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/loyalty/presentation/screens/loyalty_screen.dart';
import '../features/messaging/presentation/screens/business_inbox_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import 'admin_more_screen.dart';
import 'admin_routes.dart';
import 'auth_gate.dart';
import 'owner_shell.dart';

final adminRouterProvider = Provider<GoRouter>((ref) => buildAdminRouter());

/// The owner app's router. The outer [ShellRoute] is [AuthGate]: whatever URL
/// is open, a signed-out user sees the login screen and a signed-in one sees
/// that URL (so a deep link survives signing in), and an ADMIN sees moderation.
/// Inside it, [OwnerShell] hosts one navigator per area.
GoRouter buildAdminRouter({String initialLocation = AdminRoutes.dashboard}) {
  // One per branch: lets the shell hide its bottom bar while a branch has a
  // detail screen pushed on top of its root (see BranchDepthObserver).
  final observers = List.generate(adminBranchPaths.length, (_) => BranchDepthObserver());

  Widget owned(Widget Function(String ownerUserId) builder) => _OwnerScreen(builder: builder);

  final screens = <Widget>[
    const DashboardScreen(showNavActions: false),
    owned((id) => BusinessInboxScreen(ownerUserId: id)),
    owned((id) => CampaignCenterScreen(ownerUserId: id)),
    owned((id) => LoyaltyScreen(ownerUserId: id)),
    owned((id) => AutomationCenterScreen(ownerUserId: id)),
    const BillingScreen(),
    const SettingsScreen(),
    const AdminMoreScreen(),
  ];

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      // `/` and unknown paths land on the dashboard.
      GoRoute(path: '/', redirect: (context, state) => AdminRoutes.dashboard),
      ShellRoute(
        builder: (context, state, child) => AuthGate(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                OwnerShell(navigationShell: navigationShell, depthObservers: observers),
            branches: [
              for (var i = 0; i < adminBranchPaths.length; i++)
                StatefulShellBranch(
                  observers: [observers[i]],
                  routes: [GoRoute(path: adminBranchPaths[i], builder: (context, state) => screens[i])],
                ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _GoToDashboard(),
  );
}

/// Resolves the signed-in owner's id for screens that take it as a constructor
/// argument (a URL can't carry it).
class _OwnerScreen extends ConsumerWidget {
  const _OwnerScreen({required this.builder});

  final Widget Function(String ownerUserId) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerUserId = ref.watch(authControllerProvider).value?.id;
    return ownerUserId == null ? const SizedBox.shrink() : builder(ownerUserId);
  }
}

class _GoToDashboard extends StatefulWidget {
  const _GoToDashboard();

  @override
  State<_GoToDashboard> createState() => _GoToDashboardState();
}

class _GoToDashboardState extends State<_GoToDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AdminRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

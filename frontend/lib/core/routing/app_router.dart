import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_notifier.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/floor_dashboard_screen.dart';
import '../../features/summary/dealership_summary_screen.dart';
import '../../features/enquiries/vehicle_picker/vehicle_picker_screen.dart';
import '../../features/enquiries/customize/customize_screen.dart';
import '../../features/enquiries/quote_actions/quote_actions_screen.dart';
import '../../features/enquiries/enquiries_list_screen.dart';
import '../../features/follow_ups/follow_ups_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/masters/masters_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/responsive_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.uri.path == '/login';
      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // If user is authenticated and on login page, route according to role:
      if (isLoggingIn) {
        final user = authState.user;
        if (user != null && user.isSalesExec) {
          // Landing-screen routing logic (RESOLVED in docs):
          // sales_exec -> lands directly on vehicle_picker (no dashboard)
          return '/enquiries/vehicle-picker';
        }
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // App Shell with Responsive Navigation
      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveScaffold(
            currentRoute: state.uri.path,
            body: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const FloorDashboardScreen(),
          ),
          GoRoute(
            path: '/summary',
            builder: (context, state) => const DealershipSummaryScreen(),
          ),
          GoRoute(
            path: '/enquiries',
            builder: (context, state) => const EnquiriesListScreen(),
          ),
          GoRoute(
            path: '/enquiries/vehicle-picker',
            builder: (context, state) => const VehiclePickerScreen(),
          ),
          GoRoute(
            path: '/enquiries/customize',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CustomizeScreen(vehicle: extra['vehicle'] ?? {});
            },
          ),
          GoRoute(
            path: '/enquiries/quote-actions',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return QuoteActionsScreen(
                enquiry: extra['enquiry'] ?? {},
                quotation: extra['quotation'] ?? {},
              );
            },
          ),
          GoRoute(
            path: '/follow-ups',
            builder: (context, state) => const FollowUpsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/masters',
            builder: (context, state) => const MastersScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

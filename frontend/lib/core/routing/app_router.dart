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
import '../../features/admin/admin_panel_screen.dart';
import '../../features/tablet_configurator/build_my_honda_screen.dart';
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

      final user = authState.user;
      final path = state.uri.path;

      // If user is authenticated and on login page, route according to role:
      if (isLoggingIn) {
        if (user != null && user.isSalesExec) {
          return '/enquiries';
        }
        return '/dashboard';
      }

      if (user == null) {
        return '/login';
      }

      // --- RBAC ROUTE PROTECTION ---

      // 0. Floor Dashboard & Dealership Summary Protection:
      // Floor Dashboard (/dashboard) is accessible ONLY to Super Admin / Owner and Branch Manager.
      // Sales Execs have NO access to dashboard and are redirected to /enquiries.
      if (path == '/dashboard' || path == '/summary') {
        if (!user.canAccessDashboard) {
          return '/enquiries';
        }
      }

      // 1. Admin Panel / Masters / Settings Protection:
      final isAdminRoute = path == '/admin' ||
          path.startsWith('/admin/') ||
          path == '/masters' ||
          path.startsWith('/masters/') ||
          path == '/settings' ||
          path.startsWith('/settings/');

      if (isAdminRoute) {
        // Sales Rep, Tele-caller, Accounts have ZERO access to Admin Panel or Masters
        if (!user.canAccessAdminPanel) {
          return user.isSalesExec ? '/enquiries/vehicle-picker' : '/enquiries';
        }

        // Branch Manager has view access to Masters, but CANNOT access Users or Company Profile
        if (user.isBranchManager) {
          if (path == '/admin/users' ||
              path == '/admin/company-profile' ||
              path == '/settings' ||
              path.startsWith('/settings/')) {
            return '/admin/vehicles';
          }
        }
      }

      // 2. Reports Protection:
      // Reports accessible by Super Admin, Branch Manager, Accounts.
      // Sales Exec and Tele Caller have ZERO access to Reports.
      if (path == '/reports' || path.startsWith('/reports/')) {
        if (!user.canAccessReports) {
          return user.isSalesExec ? '/enquiries/vehicle-picker' : '/enquiries';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Full-screen Tablet POS & Live Enquiry Customizer (matching prototype)
      GoRoute(
        path: '/tablet',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final repId = state.uri.queryParameters['repId'];
          return CustomizeScreen(
            vehicle: extra['vehicle'] ?? {},
            initialRepId: repId,
          );
        },
      ),
      // Full-screen "Build My Honda" Showroom Tablet Configurator (7-step visual wizard)
      GoRoute(
        path: '/build-my-honda',
        builder: (context, state) {
          final repId = state.uri.queryParameters['repId'];
          return BuildMyHondaScreen(initialRepId: repId);
        },
      ),
      GoRoute(
        path: '/tablet-configurator',
        builder: (context, state) {
          final repId = state.uri.queryParameters['repId'];
          return BuildMyHondaScreen(initialRepId: repId);
        },
      ),
      GoRoute(
        path: '/enquiries/customize',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final repId = state.uri.queryParameters['repId'];
          return CustomizeScreen(
            vehicle: extra['vehicle'] ?? {},
            initialRepId: repId,
          );
        },
      ),

      // App Shell with Responsive Navigation Rail
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
            path: '/admin',
            redirect: (context, state) => '/admin/vehicles',
          ),
          GoRoute(
            path: '/admin/:section',
            builder: (context, state) {
              final section = state.pathParameters['section'] ?? 'vehicles';
              return AdminPanelScreen(section: section);
            },
          ),
          GoRoute(
            path: '/masters',
            redirect: (context, state) => '/admin/vehicles',
          ),
          GoRoute(
            path: '/settings',
            redirect: (context, state) => '/admin/company-profile',
          ),
        ],
      ),
    ],
  );
});

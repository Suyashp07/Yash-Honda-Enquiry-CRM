import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Landing-screen routing logic (RESOLVED in docs):
// sales_exec -> lands directly on features/enquiries/vehicle_picker (no dashboard)
// branch_manager / super_admin -> lands on features/dashboard (Floor Dashboard)

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth/login',
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login Screen')),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Floor Dashboard (RIGID)')),
        ),
      ),
      GoRoute(
        path: '/summary',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Dealership Summary - Matrix/Exec/Financial (RIGID)')),
        ),
      ),
      GoRoute(
        path: '/enquiries/vehicle-picker',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Unified Enquiry Flow: Vehicle Picker')),
        ),
      ),
    ],
  );
});


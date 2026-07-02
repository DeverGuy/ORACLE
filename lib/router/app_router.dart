import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/providers.dart';

// Home / Landing
import '../features/home/screens/landing_screen.dart';

// Auth
import '../features/auth/screens/login_screen.dart';

// Dashboards (Placeholder for now, we will use the existing ones for org/admin)
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/dashboard/screens/pending_verification_screen.dart';
import '../features/payments/screens/payment_screen.dart';
import '../features/payments/screens/manual_entry_screen.dart';
import '../features/students/screens/student_ledger_screen.dart';
import '../features/settings/screens/fee_structure_screen.dart';
import '../features/students/screens/manage_users_screen.dart';

final authNotifier = ValueNotifier<bool>(Supabase.instance.client.auth.currentSession != null);

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  
  // Update notifier when auth state changes
  supabase.auth.onAuthStateChange.listen((data) {
    authNotifier.value = data.session != null;
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.value;
      
      // If we are on the landing page, stay there regardless of auth
      if (state.matchedLocation == '/') return null;

      final isLoginRoute = state.matchedLocation.endsWith('/login');

      if (!isLoggedIn && !isLoginRoute) {
        // If they try to access a protected route without login, 
        // send them to the appropriate login page based on URL prefix
        if (state.matchedLocation.startsWith('/admin')) return '/admin/login';
        if (state.matchedLocation.startsWith('/org')) return '/org/login';
        if (state.matchedLocation.startsWith('/portal')) return '/portal/login';
        return '/';
      }

      if (isLoggedIn && isLoginRoute) {
        // If they are logged in and hit a login page, redirect to their dashboard
        if (state.matchedLocation.startsWith('/admin')) return '/admin/dashboard';
        if (state.matchedLocation.startsWith('/org')) return '/org/dashboard';
        if (state.matchedLocation.startsWith('/portal')) return '/portal/dashboard';
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const LandingScreen(),
      ),
      
      // ==========================================
      // ADMIN PORTAL
      // ==========================================
      GoRoute(
        path: '/admin/login',
        builder: (ctx, _) => const LoginScreen(portalType: 'admin'),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (ctx, _) => const AdminDashboardScreen(),
      ),

      // ==========================================
      // ORGANIZATION PORTAL
      // ==========================================
      GoRoute(
        path: '/org/login',
        builder: (ctx, _) => const LoginScreen(portalType: 'org'),
      ),
      GoRoute(
        path: '/org/dashboard',
        builder: (ctx, _) => const DashboardScreen(), // Existing dashboard is for Org
        routes: [
          GoRoute(
            path: 'pending-verification',
            builder: (ctx, _) => const PendingVerificationScreen(),
          ),
          GoRoute(
            path: 'fee-structures',
            builder: (ctx, _) => const FeeStructureScreen(),
          ),
          GoRoute(
            path: 'manual-entry',
            builder: (ctx, _) => const ManualEntryScreen(),
          ),
          GoRoute(
            path: 'manage-users',
            builder: (ctx, _) => const ManageUsersScreen(),
          ),
          GoRoute(
            path: 'student/:studentId/ledger',
            builder: (ctx, state) => StudentLedgerScreen(
              studentId: state.pathParameters['studentId']!,
            ),
          ),
          GoRoute(
            path: 'payment/:allocationId',
            builder: (ctx, state) => PaymentScreen(
              allocationId: state.pathParameters['allocationId']!,
            ),
          ),
        ],
      ),

      // ==========================================
      // STUDENT & PARENT PORTAL
      // ==========================================
      GoRoute(
        path: '/portal/login',
        builder: (ctx, _) => const LoginScreen(portalType: 'portal'),
      ),
      GoRoute(
        path: '/portal/dashboard',
        builder: (ctx, _) => const Scaffold(
          body: Center(child: Text("Student / Parent Dashboard (Coming Soon)", style: TextStyle(color: Colors.white, fontSize: 24))),
          backgroundColor: Color(0xFF080C14), // AppColors.bg0 equivalent
        ),
      ),
    ],
  );
});

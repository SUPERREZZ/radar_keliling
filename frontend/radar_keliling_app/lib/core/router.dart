import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/radar/screens/radar_screen.dart';
import '../features/merchant_profile/screens/merchant_profile_screen.dart';
import '../features/merchant_profile/screens/edit_profile_screen.dart';
import '../features/merchant_profile/screens/menu_list_screen.dart';
import '../features/selling/screens/selling_home_screen.dart';
import '../features/call/screens/call_history_screen.dart';
import '../features/call/screens/call_detail_screen.dart';
import '../features/review/screens/review_form_screen.dart';
import '../features/admin/screens/admin_reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/radar',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/verify');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        return user.isMerchant ? '/selling' : '/radar';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return VerifyEmailScreen(email: email);
        },
      ),
      // Buyer routes
      GoRoute(path: '/radar', builder: (_, __) => const RadarScreen()),
      GoRoute(
        path: '/merchant/:id',
        builder: (_, state) =>
            MerchantProfileScreen(merchantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/merchant/:id/menus',
        builder: (_, state) =>
            MenuListScreen(merchantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/calls',
        builder: (_, __) => const CallHistoryScreen(),
      ),
      GoRoute(
        path: '/calls/:id',
        builder: (_, state) =>
            CallDetailScreen(callId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/calls/:id/review',
        builder: (_, state) =>
            ReviewFormScreen(callId: state.pathParameters['id']!),
      ),
      // Merchant routes
      GoRoute(path: '/selling', builder: (_, __) => const SellingHomeScreen()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      // Admin routes
      GoRoute(
        path: '/admin/reports',
        builder: (_, __) => const AdminReportsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.error}')),
    ),
  );
});

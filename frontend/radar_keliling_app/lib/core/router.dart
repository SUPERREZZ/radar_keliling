import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/user_model.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/radar/screens/buyer_shell.dart';
import '../features/merchant_profile/screens/merchant_profile_screen.dart';
import '../features/merchant_profile/screens/edit_profile_screen.dart';
import '../features/merchant_profile/screens/merchant_menu_screen.dart';
import '../features/merchant_profile/screens/menu_list_screen.dart';
import '../features/selling/screens/selling_home_screen.dart';
import '../features/call/screens/call_history_screen.dart';
import '../features/call/screens/call_detail_screen.dart';
import '../features/review/screens/review_form_screen.dart';
import '../features/admin/screens/admin_reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshStream(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      // Splash screen menentukan tujuan awal sendiri.
      if (location == '/splash') {
        return null;
      }

      // Biarkan splash/loading pertama berjalan.
      if (authState.isLoading && authState.valueOrNull == null) {
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute =
          location == '/login' ||
          location == '/register' ||
          location.startsWith('/verify');

      // Not logged in + trying to access protected route → login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in + on auth route → dashboard sesuai role
      if (isLoggedIn && isAuthRoute) {
        return user.homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginScreen(initialEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final token = state.uri.queryParameters['token'];
          final extra = state.extra;
          return VerifyEmailScreen(
            email: email,
            token: token,
            password: extra is String ? extra : null,
          );
        },
      ),
      // Buyer routes
      GoRoute(path: '/radar', builder: (_, __) => const BuyerShell()),
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
      GoRoute(path: '/calls', builder: (_, __) => const CallHistoryScreen()),
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
      GoRoute(
        path: '/profile/menus',
        builder: (_, __) => const MerchantMenuScreen(),
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

/// Helper to make GoRouter refresh when auth state changes.
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Ref ref) {
    _subscription = ref.listen<AsyncValue<UserModel?>>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<UserModel?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

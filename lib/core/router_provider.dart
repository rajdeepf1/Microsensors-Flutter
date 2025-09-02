import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:microsensors/features/my_account/presentation/MyAccount.dart';
import 'package:microsensors/features/notification/presentation/notification.dart';
import 'package:microsensors/features/product_list/presentation/product_list.dart';
import 'package:microsensors/features/user_list/presentation/users_list.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'go_router_refresh_stream.dart';



final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefresh(ref),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        //redirect: (context, state) => !isLoggedIn ? '/login' : null,
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersList(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductList(),
      ),
      GoRoute(
        path: '/my-account',
        builder: (context, state) => const MyAccount(),
      ),
      GoRoute(
        path: '/notification',
        builder: (context, state) => const Notification(),
      ),
    ],
  );
});

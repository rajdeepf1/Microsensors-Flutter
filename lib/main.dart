import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:microsensors/features/auth/presentation/signup_screen.dart';
import 'core/go_router_refresh_stream.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/splash_screen/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home_screen/presentation/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authProvider.notifier);

    final router = GoRouter(
      initialLocation: '/', // Always start at splash
      refreshListenable: GoRouterRefreshStream(authNotifier.authStateChanges),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],

    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white, appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue, // AppBar color
        foregroundColor: Colors.white, // Text/Icon color
        //centerTitle: true,
        elevation: 4,
      ),),
    );
  }
}

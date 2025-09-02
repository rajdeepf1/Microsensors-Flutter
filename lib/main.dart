import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:microsensors/utils/colors.dart';
import 'core/router_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

/// Main App
class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider); // 👈 Watch router

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.app_blue_color,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
    );
  }
}

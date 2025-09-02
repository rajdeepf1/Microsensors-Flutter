import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../components/main_layout/main_layout.dart';
import '../../components/bottom_navigation_bar/bottom_navigation_bar.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MainLayout(
      title: "Home",
      child: AppBottomNavigationBar(),
      isHome: true,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../components/main_layout/main_layout.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MainLayout(
      title: "Home",
      child: Center(child: Text("Home Screen")),
    );
  }
}

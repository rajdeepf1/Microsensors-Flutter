import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';

class Notification extends StatelessWidget {
  const Notification({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(title: "Notifications", screenType: ScreenType.search_calender,child: Text("Notifications"));
  }
}

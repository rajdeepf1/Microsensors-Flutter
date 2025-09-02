import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/dashboard/presentation/dashboard.dart';
import 'package:microsensors/features/profile/presentation/profile.dart';
import 'package:microsensors/utils/colors.dart';

class AppBottomNavigationBar extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // useState replaces setState and StatefulWidget
    final currentIndex = useState(0);

    final pages = [Center(child: Dashboard()), Center(child: ProfileScreen())];

    return Scaffold(
      body: pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.app_blue_color,
        currentIndex: currentIndex.value,
        onTap: (index) {
          currentIndex.value = index; // updates UI
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              size: 30,
              color: AppColors.bottom_nav_icon_color,
            ),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person,
              size: 30,
              color: AppColors.bottom_nav_icon_color,
            ),
            label: "",
          ),
        ],
      ),
    );
  }
}

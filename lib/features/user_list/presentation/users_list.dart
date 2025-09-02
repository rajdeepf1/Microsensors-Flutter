import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';

import '../../../utils/colors.dart';

class UsersList extends StatelessWidget {
  const UsersList({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MainLayout(
        title: "Users",
        tabBar: TabBar(
          tabs: const [
            Tab(text: "Sales Persons",),
            Tab(text: "Production Managers"),
          ],
          labelColor: AppColors.tab_text_color,
          automaticIndicatorColorAdjustment: true,
          unselectedLabelColor: AppColors.tab_text_color,
          indicatorColor: AppColors.tab_indicator_color,
        ),
        child: const TabBarView(
          children: [
            Center(child: Text("Sales Persons List")),
            Center(child: Text("Production Managers List")),
          ],
        ),
      ),
    );
  }
}

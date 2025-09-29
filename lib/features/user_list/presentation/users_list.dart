import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/user_list/presentation/production_manager_user_list.dart';
import 'package:microsensors/features/user_list/presentation/sales_user_list.dart';

import '../../../utils/colors.dart';

class UsersList extends StatelessWidget {
  const UsersList({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MainLayout(
        title: "Users",
        screenType: ScreenType.tab,
        tabBar: TabBar(
          tabs: const [
            Tab(text: "Sales Persons",),
            Tab(text: "Production Managers"),
          ],
          labelColor: AppColors.tabTextColor,
          automaticIndicatorColorAdjustment: true,
          unselectedLabelColor: AppColors.tabTextColor,
          indicatorColor: AppColors.tabIndicatorColor,
        ),
        child: SafeArea(
          top: false, // keep AppBar/tabBar at the top edge
          bottom: true, // protect from bottom insets
          child: TabBarView(
          children: [
            Center(child: SalesUserListScreen()),
            Center(child: ProductionManagerUserList()),
          ],
        ),)
      ),
    );
  }
}

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
        child: TabBarView(
          children: [
            Center(child: SalesUserListScreen()),
            Center(child: ProductionManagerUserList()),
          ],
        ),
      ),
    );
  }
}

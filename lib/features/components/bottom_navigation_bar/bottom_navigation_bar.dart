import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/features/dashboard/presentation/dashboard.dart';
import 'package:microsensors/features/profile/presentation/profile.dart';
import 'package:microsensors/features/sales_user_dashboard/presentation/sales_user_dashboard.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/utils/colors.dart';

import '../../../core/local_storage_service.dart';
import '../../production_user_dashboard/presentation/production_user_dashboard.dart';

class AppBottomNavigationBar extends HookWidget {
  const AppBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    // reactive holder for fetched user (null while loading)
    final localUser = useState<UserDataModel?>(null);
    final isLoading = useState<bool>(true);

    // fetch once
    useEffect(() {
      var cancelled = false;
      () async {
        try {
          final u = await LocalStorageService().getUser();
          if (!cancelled) {
            localUser.value = u;
          }
        } catch (e) {
          // handle error if needed
          if (!cancelled) localUser.value = null;
        } finally {
          if (!cancelled) isLoading.value = false;
        }
      }();
      return () {
        cancelled = true;
      };
    }, const []);

    final currentIndex = useState(0);

    // if still loading show loader
    if (isLoading.value) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // build pages after we have the user
    final String storedUserRole = localUser.value?.roleName ?? '';

    Widget? screen;

    switch(storedUserRole){

      case 'Admin': screen = Dashboard();
      case 'Sales': screen = SalesUserDashboard();
      case 'Production Manager': screen = ProductionUserDashboard();

      default: context.go("/login");

    }

    final pages = [
      Center(child: screen),
      const Center(child: ProfileScreen()),
    ];

    return Scaffold(
      body: SafeArea(child: pages[currentIndex.value],bottom: true,top: true,),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.appBlueColor,
        currentIndex: currentIndex.value,
        onTap: (index) {
          currentIndex.value = index; // updates UI
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30, color: AppColors.bottomNavIconColor),
            label: "",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 30, color: AppColors.bottomNavIconColor),
            label: "",
          ),
        ],
      ),
    );
  }
}

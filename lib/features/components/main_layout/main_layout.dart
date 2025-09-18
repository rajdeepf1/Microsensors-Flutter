import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/utils/sizes.dart';
import '../../../core/app_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../smart_image/smart_image.dart';

class MainLayout extends HookWidget {
  final String title;
  final Widget child;
  final bool isHome;
  final TabBar? tabBar;

  const MainLayout({
    super.key,
    required this.title,
    required this.child,
    this.isHome = false,
    this.tabBar,
  });

  @override
  Widget build(BuildContext context) {

// currentUser is a UserDataModel? (comes from AppState's ValueNotifier)
    final UserDataModel? currentUser = useValueListenable(AppState.instance.currentUser);

    final username = currentUser?.username ?? 'User';
    final role = currentUser?.roleName ?? 'Guest';
    final userImage = currentUser?.userImage; // may be null or relative path

    return Scaffold(
      appBar: isHome
          ? AppBar(
        toolbarHeight: 100,
        elevation: 5,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                AppSizes.userImageRadius,
              ),
              child:

              SmartImage(
                imageUrl: userImage,
                baseUrl: Constants.apiBaseUrl,
                width: 70,
                height: 70,
                shape: ImageShape.circle,
                username: username,
              ),


            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $username!",
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.whiteTextColor,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.whiteTextColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                size: 30,
              ),
              onPressed: () {
                // Your action here
                context.push("/notification");
              },
            ),

          ],
        ),
      )
          : AppBar(
        title: Text(
          title,
          style: TextStyle(color: AppColors.whiteTextColor),
        ),
        elevation: 5,
        bottom: tabBar,
      ),
      body: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/utils/sizes.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';

class MainLayout extends StatelessWidget {
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
                AppSizes.userImage_radius,
              ),
              child:
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.userImage_radius),
                child: Image.network(
                  Constants.user_default_image,
                  height: 70,
                  width: 70,
                  fit: BoxFit.cover,
                ),
              ),

            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello User!",
                  style: TextStyle(
                    fontSize: 26,
                    color: AppColors.white_text_color,
                  ),
                ),
                Text(
                  "Admin",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.white_text_color,
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
                print("Notification icon clicked");
                context.push("/notification");
              },
            ),

          ],
        ),
      )
          : AppBar(
        title: Text(
          title,
          style: TextStyle(color: AppColors.white_text_color),
        ),
        elevation: 5,
        bottom: tabBar,
      ),
      body: child,
    );
  }
}

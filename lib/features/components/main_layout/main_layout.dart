import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/utils/sizes.dart';
import '../../../core/app_state.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../smart_image/smart_image.dart';

enum ScreenType {
  home,
  search,
  tab,
  home_search,
  search_calender
}


class MainLayout extends HookWidget {
  final String title;
  final Widget child;
  final ScreenType screenType;
  final TabBar? tabBar;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<DateTimeRange?>? onDateRangeChanged;

  const MainLayout({
    super.key,
    required this.title,
    required this.child,
    this.screenType = ScreenType.tab,
    this.tabBar,
    this.onSearchChanged,
    this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = useValueListenable(AppState.instance.currentUser);
    final username = currentUser?.username ?? 'User';
    final role = currentUser?.roleName ?? 'Guest';
    final userImage = currentUser?.userImage;

    return Scaffold(
      appBar: _buildAppBar(context, username, role, userImage),
      body: child,
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, String username, String role, String? userImage) {
    switch (screenType) {
      case ScreenType.home:
        return AppBar(
          toolbarHeight: 100,
          elevation: 5,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.userImageRadius),
                child: SmartImage(
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
                  Text("Hello, $username!",
                      style: TextStyle(
                          fontSize: 18, color: AppColors.whiteTextColor)),
                  Text(role,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.whiteTextColor)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 30),
                onPressed: () => context.push("/notification"),
              ),
            ],
          ),
        );
        
      case ScreenType.search:

        final isSearching = useState(false);
        final searchController = useTextEditingController();

        return AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: isSearching.value
                ? Container(
              key: const ValueKey("searchField"),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), // background color
                borderRadius: BorderRadius.circular(28), // rounded corners
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                onChanged: (value) {
                  debugPrint("🔍 Searching for: $value");
                  onSearchChanged?.call(value);
                },
                onSubmitted: (value) {
                  onSearchChanged?.call(value);
                },
              ),
            )
                : Text(
              title,
              key: const ValueKey("titleText"),
              style: TextStyle(color: AppColors.whiteTextColor),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isSearching.value ? Icons.close : Icons.search,
                size: 28,
              ),
              onPressed: () {
                if (isSearching.value) {
                  // closing search
                  isSearching.value = false;
                  searchController.clear();
                  onSearchChanged?.call("");
                } else {
                  // opening search
                  isSearching.value = true;
                }
              },
            ),
          ],
          elevation: 5,
        );

      case ScreenType.tab:
        return AppBar(
            title: Text(title, style: TextStyle(color: AppColors.whiteTextColor)),
            elevation: 5,
            bottom: tabBar,
        );

      case ScreenType.home_search:
        return AppBar(
          toolbarHeight: 100,
          elevation: 5,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.userImageRadius),
                child: SmartImage(
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
                  Text("Hello, $username!",
                      style: TextStyle(
                          fontSize: 18, color: AppColors.whiteTextColor)),
                  Text(role,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.whiteTextColor)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, size: 30),
                onPressed: () => context.push("/production-manager-history-search"),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, size: 30),
                onPressed: () => context.push("/notification"),
              ),
            ],
          ),
        );

      case ScreenType.search_calender:

        final isSearching = useState(false);
        final searchController = useTextEditingController();

        // show date range picker and call callback
        Future<void> _openDateRangePicker(BuildContext ctx) async {
          final now = DateTime.now();
          final last30 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
          final picked = await showDateRangePicker(
            context: ctx,
            firstDate: DateTime(2000),
            lastDate: DateTime(now.year + 1),
            initialDateRange: DateTimeRange(start: last30, end: now),
            builder: (context, child) => Theme(
              data: Theme.of(context),
              child: child!,
            ),
          );
          // pass the picked range back to parent via callback
          // note: MainLayout must now accept onDateRangeChanged in constructor
          if (picked != null) {
            onDateRangeChanged?.call(picked);
          } else {
            // user cancelled -> no change (or you could call with null to clear)
          }
        }

        return AppBar(
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: isSearching.value
                ? Container(
              key: const ValueKey("searchField"),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), // background color
                borderRadius: BorderRadius.circular(28), // rounded corners
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                onChanged: (value) {
                  debugPrint("🔍 Searching for: $value");
                  onSearchChanged?.call(value);
                },
                onSubmitted: (value) {
                  onSearchChanged?.call(value);
                },
              ),
            )
                : Text(
              title,
              key: const ValueKey("titleText"),
              style: TextStyle(color: AppColors.whiteTextColor),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                isSearching.value ? Icons.close : Icons.search,
                size: 28,
              ),
              onPressed: () {
                if (isSearching.value) {
                  // closing search
                  isSearching.value = false;
                  searchController.clear();
                  onSearchChanged?.call("");
                } else {
                  // opening search
                  isSearching.value = true;
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month, size: 28),
              onPressed: () => _openDateRangePicker(context),
            ),
          ],
          elevation: 5,
        );

    }
  }
}

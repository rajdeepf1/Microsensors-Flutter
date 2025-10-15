import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/models/notification/notification_model.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/core/local_storage_service.dart';

import '../repository/notification_repository.dart';

class Notification extends HookWidget {
  const Notification({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => NotificationRepository());
    final userFuture = useMemoized(() => LocalStorageService().getUser());

    const int pageSize = 20;
    const int initialPage = 0;

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>('');
    final debounceRef = useRef<Timer?>(null);
    final dateRange = useState<DateTimeRange?>(null);

    final userRole = useState<String>('');
    final userId = useState<int?>(null);

    String? _normalizeSearch(String? q) {
      if (q == null) return null;
      final t = q.trim();
      return t.isEmpty ? null : t;
    }

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final pagingController = useMemoized(
          () => PagingController<int, NotificationModel>(
        getNextPageKey: (PagingState<int, NotificationModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return initialPage;

          final lastKey = (state.keys?.isNotEmpty ?? false)
              ? state.keys!.last
              : (initialPage + state.pages!.length - 1);

          if (totalPages.value != null && lastKey >= (totalPages.value! - 1)) {
            return null;
          }

          return lastKey + 1;
        },
        fetchPage: (int pageKey) async {
          debugPrint('Notifications.fetchPage: page=$pageKey, q="${searchQuery.value}"');

          // ensure user loaded
          final storedUser = await userFuture;

          switch(storedUser!.roleName.toUpperCase()){
            case "ADMIN": userRole.value = "ADMIN";
            case "SALES": userRole.value = "SALES";
            case "PRODUCTION MANAGER": userRole.value = "PM";
          }

          userId.value = storedUser?.userId;

          final res = await repo.fetchNotificationsPage(
            role: userRole.value,
            userId: userId.value,
            page: pageKey,
            size: pageSize,
            search: _normalizeSearch(searchQuery.value),
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
          );

          if (res is ApiError<NotificationPageResult>) {
            throw Exception(res.message);
          }

          if (res is ApiData<NotificationPageResult>) {
            final pageResult = res.data;
            final items = pageResult.items;
            final total = pageResult.total ?? 0;

            if (totalPages.value == null) {
              totalPages.value = total > 0 ? ((total + pageSize - 1) ~/ pageSize) : 0;
              debugPrint('Notifications: totalPages=${totalPages.value}, total=$total');
            }

            return items;
          }

          return <NotificationModel>[];
        },
      ),
      [repo, searchQuery.value, dateRange.value],
    );

    void _onDateRangeChanged(DateTimeRange? picked) {
      dateRange.value = picked;
      totalPages.value = null;
      try {
        pagingController.refresh();
      } catch (_) {}
    }

    useEffect(() {
      try {
        pagingController.fetchNextPage();
      } catch (_) {
        try {
          pagingController.refresh();
        } catch (_) {}
      }

      return () {
        debounceRef.value?.cancel();
        try {
          pagingController.dispose();
        } catch (_) {}
      };
    }, [pagingController]);

    void onSearchChanged(String q) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(const Duration(milliseconds: 400), () {
        final trimmed = q.trim();
        if (trimmed == searchQuery.value) return;

        searchQuery.value = trimmed;
        totalPages.value = null;

        try {
          pagingController.refresh();
        } catch (_) {}
      });
    }

    return MainLayout(
      title: "Notifications",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: PagingListener<int, NotificationModel>(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          if (state.isLoading && (state.pages?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && (state.pages?.isEmpty ?? true)) {
            return Center(
              child: ElevatedButton(
                onPressed: () => fetchNextPage(),
                child: const Text('Retry'),
              ),
            );
          }

          if (state.pages?.isEmpty ?? true) {
            return const Center(child: Text('No notifications found'));
          }

          return SafeArea(
            top: false,
            bottom: true,
            child: PagedListView<int, NotificationModel>(
              state: state,
              fetchNextPage: fetchNextPage,
              padding: const EdgeInsets.all(16),
              builderDelegate: PagedChildBuilderDelegate<NotificationModel>(
                itemBuilder: (context, notification, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: NotificationCardWidget(notification: notification),
                  );
                },
                firstPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
                newPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
                firstPageErrorIndicatorBuilder: (_) => Center(
                  child: ElevatedButton(
                    onPressed: () => fetchNextPage(),
                    child: const Text('Retry'),
                  ),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                const Center(child: Text('No notifications found')),
                noMoreItemsIndicatorBuilder: (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No more notifications')),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NotificationCardWidget extends StatelessWidget {
  final NotificationModel notification;

  const NotificationCardWidget({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Colors.black54;

    return Card(
      elevation: 2,
      color: notification.isRead ? Colors.white : AppColors.pillActiveBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              notification.body,
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  notification.type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.appBlueColor,
                  ),
                ),
                Text(
                  notification.formattedCreatedAt,
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


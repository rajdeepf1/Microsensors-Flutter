import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/core/local_storage_service.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/models/notification/notification_model.dart';
import 'package:microsensors/utils/colors.dart';
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
    final hasMarkedRead = useState<bool>(false);

    final allNotifications = useState<List<NotificationModel>>([]);
    final selectedIds = useState<Set<int>>({});
    final isSelectionMode = useState<bool>(false);
    final isDeleting = useState<bool>(false);

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
          final storedUser = await userFuture;
          if (storedUser == null) throw Exception("User not found");

          switch (storedUser.roleName.toUpperCase()) {
            case "ADMIN":
              userRole.value = "ADMIN";
              break;
            case "SALES":
              userRole.value = "SALES";
              break;
            case "PRODUCTION MANAGER":
              userRole.value = "PM";
              break;
          }

          userId.value = storedUser.userId;

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
              totalPages.value =
              total > 0 ? ((total + pageSize - 1) ~/ pageSize) : 0;
            }

            final updatedList = [...allNotifications.value, ...items];
            allNotifications.value = updatedList;
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
      allNotifications.value = [];
      pagingController.refresh();
    }

    useEffect(() {
      pagingController.fetchNextPage();
      return () {
        debounceRef.value?.cancel();
        pagingController.dispose();
      };
    }, [pagingController]);

    void onSearchChanged(String q) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(const Duration(milliseconds: 400), () {
        final trimmed = q.trim();
        if (trimmed == searchQuery.value) return;

        searchQuery.value = trimmed;
        totalPages.value = null;
        allNotifications.value = [];
        pagingController.refresh();
      });
    }

    Future<void> _deleteSelected() async {
      if (selectedIds.value.isEmpty || isDeleting.value) return;

      final backup = List<NotificationModel>.from(allNotifications.value);
      final idsToDelete = selectedIds.value.toList();

      // ✅ Optimistic UI update
      allNotifications.value
          .removeWhere((n) => idsToDelete.contains(n.notificationId));
      selectedIds.value.clear();
      isSelectionMode.value = false;

      // ✅ Show snackbar (Undo option)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${idsToDelete.length} notification${idsToDelete.length > 1 ? 's' : ''} deleted',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              allNotifications.value = backup;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );

      // ✅ Wait a bit (2s) for Undo chance before calling backend
      await Future.delayed(const Duration(seconds: 2));

      final storedUser = await userFuture;
      if (storedUser == null) return;

      final res = await repo.deleteNotifications(
        userId: storedUser.userId!,
        notificationIds: idsToDelete,
      );

      if (res is ApiData<String>) {
        debugPrint("✅ Notifications deleted from backend successfully");

        totalPages.value = null;

        // ✅ Force fetch new data
        pagingController.refresh();
        await Future.delayed(const Duration(milliseconds: 100));
        pagingController.fetchNextPage();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications deleted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (res is ApiError<String>) {
        // 🔹 Revert UI if API fails
        allNotifications.value = backup;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to delete notifications'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // ✅ Safe post-frame SnackBar logic
    useEffect(() {
      if (isSelectionMode.value && selectedIds.value.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final count = selectedIds.value.length;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: Colors.grey.shade900,
                content: Text(
                  '$count selected',
                  style: const TextStyle(color: Colors.white),
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(days: 1),
                action: SnackBarAction(
                  label: 'Delete',
                  textColor: Colors.redAccent,
                  onPressed: _deleteSelected,
                ),
              ),
            );
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        });
      }
      return null;
    }, [selectedIds.value]);

    useEffect(() {
      () async {
        // Don’t run if list empty or already marked
        if (allNotifications.value.isEmpty || hasMarkedRead.value) return;

        // Check if any unread notification exists
        final hasUnread = allNotifications.value.any((n) => n.isRead == false);
        if (!hasUnread) return;

        final storedUser = await userFuture;
        if (storedUser == null || storedUser.userId == null) return;

        final ids = allNotifications.value
            .where((n) => n.isRead == false)
            .map((n) => n.notificationId)
            .whereType<int>()
            .toList();

        if (ids.isEmpty) return;

        final res = await repo.markAsRead(
          userId: storedUser.userId!,
          notificationIds: ids,
        );

        if (res is ApiData) {
          debugPrint("✅ Marked all unread notifications as read");
          // Update locally
          for (final n in allNotifications.value) {
            n.isRead = true;
          }
          allNotifications.value = [...allNotifications.value];
          hasMarkedRead.value = true; // prevent re-triggering
        }
      }();
      return null;
    }, [allNotifications.value]);

    return MainLayout(
      title: "Notifications",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: Column(
        children: [
          // 🔹 Top header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSelectionMode.value
                      ? "${selectedIds.value.length} selected"
                      : "All Notifications",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelectionMode.value
                        ? Colors.redAccent
                        : Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (isSelectionMode.value) {
                      isSelectionMode.value = false;
                      selectedIds.value = {};
                    } else {
                      isSelectionMode.value = true;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelectionMode.value
                          ? Colors.redAccent.withOpacity(0.1)
                          : AppColors.pillActiveBgColor,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelectionMode.value
                              ? Icons.close
                              : Icons.check_box_outlined,
                          size: 18,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSelectionMode.value ? "Cancel" : "Select",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
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

                return PagedListView<int, NotificationModel>(
                  state: state,
                  fetchNextPage: fetchNextPage,
                  padding: const EdgeInsets.all(16),
                  builderDelegate:
                  PagedChildBuilderDelegate<NotificationModel>(
                    itemBuilder: (context, notification, index) {
                      final selected = selectedIds.value
                          .contains(notification.notificationId);
                      return GestureDetector(
                        onLongPress: () {
                          isSelectionMode.value = true;
                          selectedIds.value = {
                            ...selectedIds.value,
                            notification.notificationId!,
                          };
                        },
                        onTap: () {
                          if (isSelectionMode.value) {
                            final updated = {...selectedIds.value};
                            if (selected) {
                              updated.remove(notification.notificationId);
                            } else {
                              updated.add(notification.notificationId!);
                            }
                            selectedIds.value = updated;
                          }
                        },
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 4.0),
                          child: NotificationCardWidget(
                            notification: notification,
                            isSelected: selected,
                            selectionMode: isSelectionMode.value,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationCardWidget extends StatelessWidget {
  final NotificationModel notification;
  final bool isSelected;
  final bool selectionMode;

  const NotificationCardWidget({
    super.key,
    required this.notification,
    required this.isSelected,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Colors.black54;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.redAccent.withOpacity(0.15)
            : (notification.isRead
            ? Colors.white
            : AppColors.pillActiveBgColor),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(notification.body,
              style: TextStyle(fontSize: 13, color: subtitleColor)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(notification.type,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.appBlueColor)),
              Text(notification.formattedCreatedAt,
                  style: TextStyle(fontSize: 12, color: subtitleColor)),
            ],
          ),
        ],
      ),
    );
  }
}

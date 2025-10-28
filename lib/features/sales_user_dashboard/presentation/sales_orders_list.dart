// lib/features/dashboard/presentation/sales_orders_list.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:microsensors/features/components/main_layout/main_layout.dart';
import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../utils/constants.dart';
import '../repository/sales_dashboard_repository.dart';
import 'orders_card.dart';

class SalesOrdersList extends HookWidget {
  const SalesOrdersList({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => SalesDashboardRepository());

    const int pageSize = 20;
    const int initialPage = 0; // backend expects 0-based

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>("");
    final debounceRef = useRef<Timer?>(null);
    final dateRange = useState<DateTimeRange?>(null);
    final selectedStatus = useState<String?>(null);

    final List<String> items = Constants.statuses;

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final pagingController = useMemoized(
      () => PagingController<int, OrderResponseModel>(
        getNextPageKey: (PagingState<int, OrderResponseModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return initialPage;

          final lastKey =
              (state.keys?.isNotEmpty ?? false)
                  ? state.keys!.last
                  : (initialPage + state.pages!.length - 1);

          if (totalPages.value != null && lastKey >= (totalPages.value! - 1)) {
            return null;
          }

          return lastKey + 1;
        },
        fetchPage: (int pageKey) async {
          debugPrint(
            'SalesOrdersList.fetchPage: page=$pageKey, q="${searchQuery.value}"',
          );

          final storedUser = await LocalStorageService().getUser();
          if (storedUser == null) throw Exception('No stored user');

          final res = await repo.fetchOrders(
            userId: storedUser.userId,
            page: pageKey,
            size: pageSize,
            q: searchQuery.value.isNotEmpty ? searchQuery.value : null,
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
            status: selectedStatus.value,
          );

          if (res is ApiError<PagedResponse<OrderResponseModel>>) {
            throw Exception(res.message);
          }

          if (res is ApiData<PagedResponse<OrderResponseModel>>) {
            final pageResult = res.data;

            if (totalPages.value == null) {
              totalPages.value = (pageResult.total + pageSize - 1) ~/ pageSize;
              debugPrint(
                'SalesOrdersList: totalPages=${totalPages.value}, total=${pageResult.total}',
              );
            }

            return pageResult.data;
          }

          return <OrderResponseModel>[];
        },
      ),
      [repo, searchQuery.value, dateRange.value, selectedStatus.value],
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

        try {
          pagingController.refresh();
        } catch (_) {}
      });
    }

    return MainLayout(
      title: 'Orders',
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Horizontal chip list
          //const SizedBox(height: 12),
          Material(
            color: Colors.white,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final status = items[index];
                    final isSelected = selectedStatus.value == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          // ✅ toggle behavior
                          if (selectedStatus.value == status) {
                            selectedStatus.value = null; // deselect
                          } else {
                            selectedStatus.value = status; // select new
                          }

                          totalPages.value = null;
                          try {
                            pagingController.refresh();
                          } catch (_) {}
                        },
                        child: _buildStatusChip(status, isSelected: isSelected),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 🔹 Orders list
          Expanded(
            child: PagingListener<int, OrderResponseModel>(
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
                  return const Center(child: Text('No orders found'));
                }

                return SafeArea(
                  top: false, // MainLayout already handles top/appbar
                  bottom: true, // protect from home indicator / gesture area
                  child: PagedListView<int, OrderResponseModel>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    padding: const EdgeInsets.all(16),
                    builderDelegate: PagedChildBuilderDelegate<
                      OrderResponseModel
                    >(
                      itemBuilder: (context, order, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: orderCardWidget(context, order),
                        );
                      },
                      firstPageProgressIndicatorBuilder:
                          (_) =>
                              const Center(child: CircularProgressIndicator()),
                      newPageProgressIndicatorBuilder:
                          (_) =>
                              const Center(child: CircularProgressIndicator()),
                      firstPageErrorIndicatorBuilder:
                          (_) => Center(
                            child: ElevatedButton(
                              onPressed: () => fetchNextPage(),
                              child: const Text('Retry'),
                            ),
                          ),
                      noItemsFoundIndicatorBuilder:
                          (_) => const Center(child: Text('No orders found')),
                      noMoreItemsIndicatorBuilder:
                          (_) => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: Text('No more orders')),
                          ),
                    ),
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

// 🔹 Small status chip widget
Widget _buildStatusChip(String status, {bool isSelected = false}) {
  final color = Constants.statusColor(status);
  final icon = Constants.statusIcon(status);

  final bgColor =
      isSelected
          ? color.withValues(alpha: 0.25)
          : color.withValues(alpha: 0.12);

  final borderColor =
      isSelected ? color.withValues(alpha: 0.5) : color.withValues(alpha: 0.16);

  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

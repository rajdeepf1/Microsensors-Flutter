import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart';
import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';
import '../repository/production_manager_repo.dart';

class ProductionManagerHistorySearch extends HookWidget {
  const ProductionManagerHistorySearch({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => ProductionManagerRepository());

    const int pageSize = 20;
    const int initialPage = 0; // backend expects 0-based

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>('');
    final debounceRef = useRef<Timer?>(null);
    final dateRange = useState<DateTimeRange?>(null);
    final selectedStatus = useState<String?>(null);

    final List<String> items = Constants.statuses.where((s) => s != 'Created').toList();

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    // PagingController — using OrderResponseModel instead of PmOrderListItem
    final pagingController = useMemoized(
          () => PagingController<int, OrderResponseModel>(
        getNextPageKey: (PagingState<int, OrderResponseModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return initialPage;

          final lastKey = (state.keys?.isNotEmpty ?? false)
              ? state.keys!.last
              : (initialPage + state.pages!.length - 1);

          if (totalPages.value != null &&
              lastKey >= (totalPages.value! - 1)) {
            return null;
          }

          return lastKey + 1;
        },
        fetchPage: (int pageKey) async {
          debugPrint(
              'PMHistory.fetchPage: page=$pageKey, q="${searchQuery.value}"');

          final storedUser = await LocalStorageService().getUser();
          if (storedUser == null) throw Exception('No stored user');

          final res = await repo.fetchOrders(
            userId: storedUser.userId,
            page: pageKey,
            size: pageSize,
            q: searchQuery.value.isNotEmpty ? searchQuery.value : null,
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
            status: selectedStatus.value
          );

          if (res is ApiError<PagedResponse<OrderResponseModel>>) {
            throw Exception(res.message);
          }

          if (res is ApiData<PagedResponse<OrderResponseModel>>) {
            final pageResult = res.data;

            if (totalPages.value == null) {
              final tot = pageResult.total ?? 0;
              totalPages.value =
              tot > 0 ? ((tot + pageSize - 1) ~/ pageSize) : 0;
              debugPrint(
                  'PMHistory: totalPages=${totalPages.value}, total=$tot');
            }

            // ✅ Filter out "CREATED" status orders (case-insensitive)
            final allItems = pageResult.data ?? [];
            final filteredItems = allItems
                .where((item) =>
            (item.status ?? '').toUpperCase() != 'CREATED')
                .toList();

            return filteredItems;
          }

          return <OrderResponseModel>[];
        },
      ),
      [repo, searchQuery.value, dateRange.value,selectedStatus.value],
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

    // ---------- UI helpers ----------
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


    Widget orderCard(BuildContext ctx, OrderResponseModel item) {
      final accent = Constants.statusColor(item.status);

      void openDetailsSheet() async {
        final bool? result = await showModalBottomSheet<bool>(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext innerCtx) {
            return FractionallySizedBox(
              heightFactor: 0.95,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: Material(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Scaffold(
                      appBar: AppBar(
                        elevation: 0,
                        backgroundColor: Colors.white,
                        iconTheme: const IconThemeData(color: Colors.black),
                        title: Text(
                          item.clientName ?? 'Order',
                          style: const TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(innerCtx).pop(),
                        ),
                      ),
                      body: PmOrderDetailsBottomSheet(
                        orderItem: item,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        if (result == true) {
          try {
            pagingController.refresh();
          } catch (_) {}
        }
      }

      return Card(
        elevation: 4,
        color: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: openDetailsSheet,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 180,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmartImage(
                              imageUrl: item.items.isNotEmpty
                                  ? item.items.first.productImage
                                  : '',
                              baseUrl: Constants.apiBaseUrl,
                              username: item.clientName,
                              shape: ImageShape.rectangle,
                              height: 120,
                              width: 120,
                              useCached: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                item.clientName ?? '',
                                                style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const WidgetSpan(
                                                  child:
                                                  SizedBox(width: 8)),
                                              TextSpan(
                                                text: '| ',
                                                style: TextStyle(
                                                  color:
                                                  Colors.blue.shade700,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              TextSpan(
                                                text: ' #${item.orderId}',
                                                style: TextStyle(
                                                  color: Colors
                                                      .grey.shade700,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Order Dt.:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              SizedBox(width: 2,),
                                              Text(
                                                Constants.timeAgo(item.createdAt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 5,),
                                          if (item.dispatchOn!=null) Row(
                                            children: [
                                              Text(
                                                'Dispatch Dt.:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              SizedBox(width: 2,),
                                              Text(
                                                Constants.timeAgo(item.dispatchOn),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          )


                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Remarks: ${item.remarks ?? "-"}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total No. Products: ${item.items.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Assigned by: ${item.salesPersonName ?? "Unassigned"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Assigned to: ${item.productionManagerName ?? "Unassigned"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatusChip(item.status ?? ''),
                            const SizedBox(width: 12),
                            _buildStatusChip(item.priority ?? ''),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MainLayout(
      title: "Search History",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: Column(
        children: [
          // 🔹 Horizontal chip list
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
                  top: false,
                  bottom: true,
                  child: PagedListView<int, OrderResponseModel>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    padding: const EdgeInsets.all(12),
                    builderDelegate: PagedChildBuilderDelegate<OrderResponseModel>(
                      itemBuilder:
                          (context, order, index) => orderCard(context, order),
                      firstPageProgressIndicatorBuilder:
                          (_) => const Center(child: CircularProgressIndicator()),
                      newPageProgressIndicatorBuilder:
                          (_) => const Center(child: CircularProgressIndicator()),
                      firstPageErrorIndicatorBuilder: (_) => Center(
                        child: ElevatedButton(
                          onPressed: () => fetchNextPage(),
                          child: const Text('Retry'),
                        ),
                      ),
                      noItemsFoundIndicatorBuilder:
                          (_) => const Center(child: Text('No orders found')),
                      noMoreItemsIndicatorBuilder: (_) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            height: 80,
                            child: Text('No more orders'),
                          ),
                        ),
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

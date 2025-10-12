import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/dashboard/repository/dashboard_repository.dart';
import 'package:microsensors/features/dashboard/presentation/admin_order_details_bottomsheet.dart';
import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';

class OrderActivities extends HookWidget {
  const OrderActivities({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => DashboardRepository());
    const int pageSize = 20;
    const int initialPage = 0;

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>('');
    final dateRange = useState<DateTimeRange?>(null);
    final debounceRef = useRef<Timer?>(null);

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    // ✅ Stable PagingController
    final pagingController = useMemoized(
          () => PagingController<int, OrderResponseModel>(
        getNextPageKey: (state) {
          if (state.pages == null || state.pages!.isEmpty) return initialPage;
          final lastKey = (state.keys?.isNotEmpty ?? false)
              ? state.keys!.last
              : (initialPage + state.pages!.length - 1);
          if (totalPages.value != null && lastKey >= (totalPages.value! - 1)) {
            return null;
          }
          return lastKey + 1;
        },
        fetchPage: (pageKey) async {
          debugPrint(
            '🔹 fetchPage: page=$pageKey, q="${searchQuery.value}", '
                'dateRange=${dateRange.value}',
          );

          final storedUser = await LocalStorageService().getUser();
          if (storedUser == null) throw Exception('No stored user');

          final res = await repo.fetchOrders(
            page: pageKey,
            size: pageSize,
            q: searchQuery.value.isNotEmpty ? searchQuery.value : null,
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
          );

          if (res is ApiError<PagedResponse<OrderResponseModel>>) {
            throw Exception(res.message);
          }

          if (res is ApiData<PagedResponse<OrderResponseModel>>) {
            final pageResult = res.data;

            if (totalPages.value == null) {
              final tot = pageResult.total;
              totalPages.value =
              tot > 0 ? ((tot + pageSize - 1) ~/ pageSize) : 0;
              debugPrint(
                  '✅ totalPages=${totalPages.value}, total=${pageResult.total}');
            }

            debugPrint('✅ fetched ${pageResult.data.length} items');
            return pageResult.data;
          }

          return <OrderResponseModel>[];
        },
      ),
      [], // keep stable
    );

    // ✅ Trigger refresh + first page fetch manually
    void _triggerRefresh() {
      totalPages.value = null;
      try {
        pagingController.refresh();
        // force first page fetch if PagingListener doesn’t auto-trigger
        Future.microtask(() => pagingController.fetchNextPage());
      } catch (_) {}
    }

    // ✅ Debounced search
    void onSearchChanged(String q) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(const Duration(milliseconds: 400), () {
        final trimmed = q.trim();
        if (trimmed == searchQuery.value) return;
        searchQuery.value = trimmed;
        _triggerRefresh();
      });
    }

    // ✅ Date range change
    void _onDateRangeChanged(DateTimeRange? picked) {
      dateRange.value = picked;
      _triggerRefresh();
    }

    // ✅ Initial fetch
    useEffect(() {
      Future.microtask(() => pagingController.fetchNextPage());
      return () {
        debounceRef.value?.cancel();
        pagingController.dispose();
      };
    }, []);

    // ---------- UI helpers ----------
    Widget _buildStatusChip(String status) {
      final color = Constants.statusColor(status);
      final icon = Constants.statusIcon(status);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.16)),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // ---------- Order Card ----------
    Widget orderCard(BuildContext ctx, OrderResponseModel item) {
      final accent = Constants.statusColor(item.status);

      Future<void> openDetailsSheet() async {
        final bool? result = await showModalBottomSheet<bool>(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AdminOrderDetailsSheet(item: item),
        );

        if (result == true) {
          _triggerRefresh(); // ✅ refresh after approval/rejection
        }
      }

      return Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: item.clientName ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const WidgetSpan(
                                                child: SizedBox(width: 8)),
                                            TextSpan(
                                              text: '| ',
                                              style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' #${item.orderId}',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      Constants.timeAgo(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
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
      );
    }

    // ---------- Main Return ----------
    return MainLayout(
      title: "Order Activities",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: PagingListener<int, OrderResponseModel>(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          if (state.isLoading && (state.pages?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && (state.pages?.isEmpty ?? true)) {
            return Center(
              child: ElevatedButton(
                onPressed: fetchNextPage,
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
                itemBuilder: (context, order, index) =>
                    orderCard(context, order),
                firstPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
                newPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
                noItemsFoundIndicatorBuilder: (_) =>
                const Center(child: Text('No orders found')),
                noMoreItemsIndicatorBuilder: (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No more orders')),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ✅ Hook-safe wrapper for AdminOrderDetailsBottomSheet
class _AdminOrderDetailsSheet extends HookWidget {
  final OrderResponseModel item;
  const _AdminOrderDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.95,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  item.clientName ?? 'Order | #${item.orderId}',
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              body: AdminOrderDetailsBottomSheet(orderItem: item),
            ),
          ),
        ),
      ),
    );
  }
}

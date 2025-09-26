import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/dashboard/repository/dashboard_repository.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart';
import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/production_manager_order_list.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';

class OrderActivities extends HookWidget {

  const OrderActivities({super.key});


  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => DashboardRepository());

    const int pageSize = 20;
    const int initialPage = 0; // backend expects 0-based

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>('');
    final debounceRef = useRef<Timer?>(null);
    final dateRange = useState<DateTimeRange?>(null);

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      // backend usually expects yyyy-MM-dd
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    // PagingController constructed in same style as SalesOrdersList
    final pagingController = useMemoized(
          () => PagingController<int, PmOrderListItem>(
        getNextPageKey: (PagingState<int, PmOrderListItem> state) {
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
          debugPrint('History.fetchPage: page=$pageKey, q="${searchQuery.value}"');

          final storedUser = await LocalStorageService().getUser();
          if (storedUser == null) throw Exception('No stored user');

          final res = await repo.fetchOrders(
            page: pageKey,
            size: pageSize,
            q: searchQuery.value.isNotEmpty ? searchQuery.value : null,
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
          );

          if (res is ApiError<PagedResponse<PmOrderListItem>>) {
            throw Exception(res.message ?? 'API error');
          }

          if (res is ApiData<PagedResponse<PmOrderListItem>>) {
            final pageResult = res.data;

            if (totalPages.value == null) {
              final tot = pageResult.total ?? 0;
              totalPages.value = tot > 0 ? ((tot + pageSize - 1) ~/ pageSize) : 0;
              debugPrint('History: totalPages=${totalPages.value}, total=${pageResult.total}');
            }

            return pageResult.data ?? <PmOrderListItem>[];
          }

          return <PmOrderListItem>[];
        },
      ),
      [repo, searchQuery.value,dateRange.value],
    );



    void _onDateRangeChanged(DateTimeRange? picked) {
      // store date range and refresh list
      dateRange.value = picked;
      totalPages.value = null; // reset cached total pages
      try {
        pagingController.refresh();
      } catch (_) {}
    }

    // initial fetch on mount
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

    // search change handler
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




    // ---------- UI helpers (kept from your original) ----------
    Color _statusColor(String? status) {
      final s = (status ?? '').toLowerCase();
      if (s == 'created') return Colors.green;
      if (s == 'received') return Colors.blue;
      if (s == 'production started') return Colors.orange;
      if (s == 'production completed') return Colors.green.shade700;
      if (s == 'dispatched') return Colors.purple;
      if (s == 'acknowledged') return Colors.teal;
      return Colors.grey.shade700;
    }

    IconData _statusIcon(String status) {
      final s = status.toLowerCase();
      if (s == 'created') return Icons.add_box_outlined;
      if (s == 'received') return Icons.inbox_outlined;
      if (s == 'production started') return Icons.play_circle_outline;
      if (s == 'production completed') return Icons.check_circle_outline;
      if (s == 'dispatched') return Icons.local_shipping_outlined;
      if (s == 'acknowledged') return Icons.done_all;
      return Icons.info_outline;
    }

    String _timeAgo(dynamic dt) {
      DateTime? date;
      if (dt == null) return '';
      if (dt is DateTime) date = dt;
      else if (dt is String) date = DateTime.tryParse(dt);
      else {
        date = DateTime.tryParse(dt.toString());
      }
      if (date == null) return '';
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      final weeks = (diff.inDays / 7).floor();
      if (weeks < 4) return '${weeks}w';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    Widget _buildStatusChip(String status) {
      final color = _statusColor(status);
      final icon = _statusIcon(status);
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

    Widget orderCard(BuildContext ctx, PmOrderListItem item) {
      final accent = _statusColor(item.currentStatus);

      void openDetailsSheet() async {
        final bool? result = await showModalBottomSheet<bool>(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext innerCtx) {
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
                          item.productName ?? 'Order',
                          style: const TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(innerCtx).pop(),
                        ),
                      ),
                      body: PmOrderDetailsBottomsheet(orderItem: item, isHistorySearchScreen: true,),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  // Left thin accent bar
                  Container(
                    width: 6,
                    height: 110,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),

                  SmartImage(
                    imageUrl: item.productImage,
                    baseUrl: Constants.apiBaseUrl,
                    username: item.productName,
                    shape: ImageShape.rectangle,
                    height: 120,
                    width: 120,
                  ),

                  const SizedBox(width: 12),

                  // content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title + time
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: item.productName ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const WidgetSpan(child: SizedBox(width: 8)),
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
                              _timeAgo(item.createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // SKU
                        Text(
                          'SKU: ${item.sku ?? "-"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),

                        const SizedBox(height: 8),

                        // qty + assigned + status
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Qty: ${item.quantity ?? 0}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Assigned by: ${item.salesPersonName ?? "Unassigned"}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Assigned to: ${item.productionManagerName ?? "Unassigned"}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(item.currentStatus ?? ''),
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

    // Build UI using PagingListener so builder has (context, state, fetchNextPage)
    return MainLayout(
      title: "Order Activities",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: PagingListener<int, PmOrderListItem>(
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

          return PagedListView<int, PmOrderListItem>(
            state: state,
            fetchNextPage: fetchNextPage,
            padding: const EdgeInsets.all(12),
            builderDelegate: PagedChildBuilderDelegate<PmOrderListItem>(
              itemBuilder: (context, order, index) => orderCard(context, order),
              firstPageProgressIndicatorBuilder: (_) => const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder: (_) => const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => Center(
                child: ElevatedButton(
                  onPressed: () => fetchNextPage(),
                  child: const Text('Retry'),
                ),
              ),
              noItemsFoundIndicatorBuilder: (_) => const Center(child: Text('No orders found')),
              noMoreItemsIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('No more orders')),
              ),
            ),
          );
        },
      ),
    );
  }
}

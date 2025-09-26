// lib/features/production_user_dashboard/presentation/production_manager_history_search.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart';

import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/production_manager_order_list.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';
import '../repository/production_manager_repo.dart';

class ProductionManagerHistorySearch extends HookWidget {
  const ProductionManagerHistorySearch({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => ProductionManagerRepository());
    final productionManager = useState<UserDataModel?>(null);
    final paged = useState<PagedResponse<PmOrderListItem>?>(null);
    final loadingOrders = useState<bool>(true);
    final error = useState<String?>(null);

    Future<void> _loadOrders() async {
      loadingOrders.value = true;
      error.value = null;
      try {
        final pmId = productionManager.value?.userId;
        if (pmId == null) {
          // no PM available yet — nothing to load
          loadingOrders.value = false;
          return;
        }
        final ApiState<PagedResponse<PmOrderListItem>> resp =
        await repo.fetchOrders(pmId: pmId, page: 0, size: 20);
        if (resp is ApiData<PagedResponse<PmOrderListItem>>) {
          paged.value = resp.data;
        } else if (resp is ApiError<PagedResponse<PmOrderListItem>>) {
          error.value = resp.message;
        }
      } catch (e) {
        error.value = 'Failed to load orders: $e';
      } finally {
        loadingOrders.value = false;
      }
    }

    // Proper useEffect pattern: create inner async function and call it
    useEffect(() {
      var mounted = true;
      () async {
        try {
          final stored = await LocalStorageService().getUser();
          if (!mounted) return;
          productionManager.value = stored;
          // only load orders after productionManager is set (or attempted)
          await _loadOrders();
        } catch (e) {
          if (!mounted) return;
          error.value = 'Init error: $e';
        }
      }();
      return () {
        mounted = false;
      };
    }, const []);

    // ---------------------------
    // Small UI helpers (declare before use)
    // ---------------------------
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
                      body: PmOrderDetailsBottomsheet(orderItem: item),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        // currently you don't process the result here; if you want to refresh
        // when bottomsheet returns true, you can do:
        if (result == true) {
          await _loadOrders();
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

    Widget buildList() {
      if (loadingOrders.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (error.value != null) {
        return Center(child: Text('Error: ${error.value}'));
      }

      final items = paged.value?.data ?? [];

      return RefreshIndicator(
        onRefresh: () async {
          await _loadOrders();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final o = items[idx];
            return orderCard(context, o);
          },
        ),
      );
    }

    return MainLayout(title: "Search", screenType: ScreenType.search, child: buildList());
  }
}

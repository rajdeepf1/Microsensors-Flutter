import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/core/local_storage_service.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/services/fcm_service.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../repository/production_manager_repo.dart';
import '../../components/smart_image/smart_image.dart';
import '../../../utils/constants.dart';

class ProductionUserDashboard extends HookWidget {
  const ProductionUserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => ProductionManagerRepository());
    final fcmService = useMemoized(() => FcmService());

    final productionManager = useState<UserDataModel?>(null);
    final paged = useState<PagedResponse<OrderResponseModel>?>(null);
    final activeStatus = useState<String>('Received'); // Default tab
    final loadingOrders = useState<bool>(true);
    final error = useState<String?>(null);

    // Static status steps
    final steps = Constants.statuses.where((s) => s != 'Created').toList();

    // 🔹 Build a small status chip widget
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

    // 🔹 Fetch orders from API
    Future<void> _loadOrders(String status) async {
      loadingOrders.value = true;
      error.value = null;
      try {
        final pmId = productionManager.value?.userId;
        if (pmId == null) {
          debugPrint('⚠️ PM userId is null, cannot load orders');
          loadingOrders.value = false;
          return;
        }

        debugPrint('🔹 Loading orders for PM ID: $pmId, status=$status');
        final ApiState<PagedResponse<OrderResponseModel>> resp =
        await repo.fetchOrders(userId: pmId, status: status, page: 0, size: 20);

        if (resp is ApiData<PagedResponse<OrderResponseModel>>) {
          paged.value = resp.data;
        } else if (resp is ApiError<PagedResponse<OrderResponseModel>>) {
          error.value = resp.message;
        }
      } catch (e) {
        error.value = 'Failed to load orders: $e';
      } finally {
        loadingOrders.value = false;
      }
    }

    // 🔹 Order Card (list item)
    Widget orderCard(BuildContext ctx, OrderResponseModel item) {
      final accent = Constants.statusColor(item.status);

      return Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // ✅ Open Hook-based bottom sheet safely
            final newStatus = await showModalBottomSheet<String>(
              context: ctx,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _PmOrderDetailsSheet(item: item),
            );

            // ✅ Refresh dashboard when status changes
            if (newStatus != null && newStatus.isNotEmpty) {
              activeStatus.value = newStatus;
              await _loadOrders(newStatus);
            }
          },
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

    // 🔹 Build order list
    Widget buildList() {
      if (loadingOrders.value) return const Center(child: CircularProgressIndicator());
      if (error.value != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${error.value}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => _loadOrders(activeStatus.value),
              ),
            ],
          ),
        );
      }

      final items = paged.value?.data ?? [];
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No data found',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => _loadOrders(activeStatus.value),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _loadOrders(activeStatus.value),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) => orderCard(context, items[idx]),
        ),
      );
    }

    // 🔹 Build status chips
    Widget buildChips() {
      return SizedBox(
        height: 72,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: steps.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = steps[i];
            final selected = s == activeStatus.value;
            return ChoiceChip(
              label: Text(
                s,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              selected: selected,
              onSelected: (_) async {
                if (activeStatus.value == s) return;
                activeStatus.value = s;
                await _loadOrders(s);
              },
              selectedColor: Constants.statusColor(s),
              backgroundColor: Colors.grey.shade200,
              elevation: 4,
              checkmarkColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          },
        ),
      );
    }

    // 🔹 Initial load
    useEffect(() {
      Future.microtask(() async {
        final user = await LocalStorageService().getUser();
        productionManager.value = user;
        if (user != null) {
          await _loadOrders(activeStatus.value);
        } else {
          error.value = 'User not found in storage';
        }
      });
      return null;
    }, []);

    // 🔹 Final layout
    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        children: [
          const SizedBox(height: 8),
          buildChips(),
          const Divider(height: 1),
          Expanded(child: buildList()),
        ],
      ),
    );
  }
}

/// ✅ Hook-safe wrapper for BottomSheet
class _PmOrderDetailsSheet extends HookWidget {
  final OrderResponseModel item;

  const _PmOrderDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final lastUpdatedStatus = useState<String?>(null);

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
                  item.clientName ?? 'Order',
                  style: const TextStyle(color: Colors.black),
                ),
                leading: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: lastUpdatedStatus.value != null
                        ? Colors.green
                        : Colors.black,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(lastUpdatedStatus.value),
                ),
              ),
              body: PmOrderDetailsBottomSheet(
                orderItem: item,
                onStatusChanged: (s) => lastUpdatedStatus.value = s,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

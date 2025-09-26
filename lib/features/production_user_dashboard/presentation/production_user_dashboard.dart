// lib/presentation/production_user_dashboard.dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/core/local_storage_service.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart';
import 'package:microsensors/models/orders/production_manager_order_list.dart'; // PmOrderListItem & PagedResponse
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/services/fcm_service.dart';

import '../../../models/orders/order_models.dart';
import '../../../models/orders/production_manager_stats.dart';
import '../repository/production_manager_repo.dart';

// If you have a SmartImage component / OrderDetailsBottomsheet adjust imports:
import '../../components/smart_image/smart_image.dart';
import '../../../utils/constants.dart';

/// Production manager dashboard:
/// - Top horizontal status pills (with counts)
/// - Beautiful list of orders filtered by status using card design from reference
class ProductionUserDashboard extends HookWidget {
  const ProductionUserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => ProductionManagerRepository());
    final fcmService = useMemoized(() => FcmService());

    // Reactive state
    final productionManager = useState<UserDataModel?>(null);
    final counts = useState<Map<String, int>>({});
    final paged = useState<PagedResponse<PmOrderListItem>?>(null);
    final activeStatus = useState<String>('Created');

    final loadingStats = useState<bool>(true);
    final loadingOrders = useState<bool>(true);
    final error = useState<String?>(null);

    const statuses = [
      'Created',
      'Received',
      'Production Started',
      'Production Completed',
      'Dispatched',
      'Acknowledged',
    ];

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
      return '${date.day}/${date.month}/${date.year}';
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

    // ---------------------------
    // Data helpers (load from repo)
    // ---------------------------
    Future<void> _loadStats() async {
      loadingStats.value = true;
      error.value = null;
      try {
        final pmId = productionManager.value?.userId;
        if (pmId == null) {
          loadingStats.value = false;
          return;
        }
        final ApiState<PmOrderStats> resp = await repo.fetchStats(pmId: pmId);
        if (resp is ApiData<PmOrderStats>) {
          counts.value = resp.data.toMap();
        } else if (resp is ApiError<PmOrderStats>) {
          error.value = resp.message;
        }
      } catch (e) {
        error.value = 'Failed to load stats: $e';
      } finally {
        loadingStats.value = false;
      }
    }

    Future<void> _loadOrders(String status) async {
      loadingOrders.value = true;
      error.value = null;
      try {
        final pmId = productionManager.value?.userId;
        if (pmId == null) {
          loadingOrders.value = false;
          return;
        }
        final ApiState<PagedResponse<PmOrderListItem>> resp =
        await repo.fetchOrders(pmId: pmId, status: status, page: 0, size: 50);
        if (resp is ApiData<PagedResponse<PmOrderListItem>>) {
          // PagedResponse should expose `content` list
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

    Future<void> _loadAll() async {
      await Future.wait([_loadStats(), _loadOrders(activeStatus.value)]);
    }

    // ---------------------------
    // Card widget (reference look)
    // ---------------------------
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
                      body: PmOrderDetailsBottomsheet(orderItem: item,isHistorySearchScreen: false,),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        // if bottomsheet returned true -> indicates something changed -> you can refresh
        if (result == true) {
          await _loadStats();
          await _loadOrders(activeStatus.value);
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

                  // thumbnail
                  //_productAvatar(item),

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



    // ---------------------------
    // useEffect: FCM init + initial load
    // ---------------------------
    useEffect(() {
      StreamSubscription<RemoteMessage>? onMessageSub;
      StreamSubscription<String>? tokenRefreshSub;
      StreamSubscription<RemoteMessage>? openedAppSub;

      final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
      const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications.',
        importance: Importance.max,
      );

      Future<void> showLocalNotification(RemoteMessage message) async {
        final notification = message.notification;
        if (notification == null) return;
        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        );
        await localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          details,
          payload: message.data.isNotEmpty ? message.data.toString() : null,
        );
      }

      // async init
      () async {
        try {
          final storedUser = await LocalStorageService().getUser();
          productionManager.value = storedUser;

          // initialize local notifications plugin
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          final initSettings = InitializationSettings(android: androidInit);
          await localNotifications.initialize(initSettings);

          // request permission and get token
          final messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(alert: true, badge: true, sound: true);
          final token = await messaging.getToken();

          if (token != null && storedUser != null) {
            final ApiState<UserDataModel> res = await fcmService.registerToken(
              userId: storedUser.userId,
              token: token,
            );
            if (res is ApiData<UserDataModel>) {
              await LocalStorageService().saveUser(res.data);
              productionManager.value = res.data;
            }
          }

          // listeners
          onMessageSub = FirebaseMessaging.onMessage.listen(showLocalNotification);
          tokenRefreshSub =
              FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
                final currentStored = await LocalStorageService().getUser();
                if (currentStored != null) {
                  final refreshRes = await fcmService.registerToken(
                    userId: currentStored.userId,
                    token: newToken,
                  );
                  if (refreshRes is ApiData<UserDataModel>) {
                    await LocalStorageService().saveUser(refreshRes.data);
                    productionManager.value = refreshRes.data;
                  }
                }
              });

          openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
            // handle navigation from notification if needed
          });

          // load after user is set (if any)
          await _loadAll();
        } catch (e, st) {
          debugPrint('Dashboard init error: $e\n$st');
          await _loadAll();
        }
      }();

      return () {
        onMessageSub?.cancel();
        tokenRefreshSub?.cancel();
        openedAppSub?.cancel();
      };
    }, const []); // run once

    // ---------------------------
    // Build UI pieces that use helpers above
    // ---------------------------
    Widget buildChips() {
      if (loadingStats.value) {
        return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()));
      }

      return SizedBox(
        height: 72,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          scrollDirection: Axis.horizontal,
          itemCount: statuses.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = statuses[i];
            final selected = s == activeStatus.value;
            final count = counts.value[s] ?? 0;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s, style: TextStyle(color: selected ? Colors.white : Colors.black87)),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: selected ? Colors.white : Colors.black26,
                    child: Text(
                      count.toString(),
                      style: TextStyle(fontSize: 12, color: selected ? Colors.black : Colors.white),
                    ),
                  ),
                ],
              ),
              selected: selected,
              onSelected: (_) async {
                if (activeStatus.value == s) return;
                activeStatus.value = s;
                await _loadOrders(s);
                await _loadStats();
              },
              selectedColor: _statusColor(s),
              backgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          },
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

      // prefer `content` field on PagedResponse if your repository maps that
      final items = paged.value?.data ?? [];

      if (items.isEmpty) {
        return Center(child: Text('No orders in "${activeStatus.value}"'));
      }

      return RefreshIndicator(
        onRefresh: () async {
          await _loadStats();
          await _loadOrders(activeStatus.value);
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (context, idx) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final o = items[idx];
            return orderCard(context, o);
          },
        ),
      );
    }

    // ---------------------------
    // Final scaffold
    // ---------------------------
    return Column(
      children: [
        const SizedBox(height: 8),
        buildChips(),
        const Divider(height: 1),
        Expanded(child: buildList()),
      ],
    );
  }
}

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

    // ---------- FCM & token registration (runs when Dashboard mounts) ----------
    useEffect(() {
      StreamSubscription<RemoteMessage>? onMessageSub;
      StreamSubscription<String>? tokenRefreshSub;
      StreamSubscription<RemoteMessage>? openedAppSub;

      final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

      // we will reuse the channel created in main.dart ("high_importance_channel")
      const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      // function to show local notification using local plugin instance
      Future<void> showLocalNotification(RemoteMessage message) async {
        final notification = message.notification;
        if (notification == null) return;

        final androidDetails = AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
        );

        final darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        );

        await localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          details,
          payload: message.data.isNotEmpty ? message.data.toString() : null,
        );
      }

      // start async block
      () async {
        try {
          // 1) Load stored user
          final storedUser = await LocalStorageService().getUser();

          // 2) initialize the local plugin (safe to call even if main already created channel)
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

          // IMPORTANT: include Darwin/iOS init settings to avoid the runtime error on iOS/macOS
          final darwinInit = DarwinInitializationSettings(
            requestAlertPermission: false, // you already request via FirebaseMessaging
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

          final initSettings = InitializationSettings(
            android: androidInit,
            iOS: darwinInit,
            macOS: darwinInit,
          );

          await localNotifications.initialize(
            initSettings,
            onDidReceiveNotificationResponse: (NotificationResponse response) {
              debugPrint('Local notification tapped. Payload: ${response.payload}');
            },
          );

          // Ensure the Android channel exists (no-op if already created)
          await localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(androidChannel);

          // 3) Request permission for notifications (iOS/Android 13+)
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.requestPermission(
            alert: true, badge: true, sound: true, provisional: false,
          );
          debugPrint('Dashboard FCM permission: ${settings.authorizationStatus}');

          // 4) Get the token (first time)
          final token = await messaging.getToken();
          debugPrint('Dashboard FCM token: $token');

          // --- SAFELY CALL registerToken and handle ApiState result ---
          if (storedUser == null) {
            debugPrint('No stored user found - skipping token registration for now.');
          } else if (token == null) {
            debugPrint('Device token is null - cannot register token.');
          } else {
            final ApiState<UserDataModel> res =
                await fcmService.registerToken(userId: storedUser.userId, token: token);

            if (res is ApiData<UserDataModel>) {
              final UserDataModel savedUser = res.data;
              await LocalStorageService().saveUser(savedUser);
              debugPrint("FCM token saved successfully and stored user updated (id=${savedUser.userId})");
            } else if (res is ApiError<UserDataModel>) {
              debugPrint("FCM token registration failed: ${res.message}");
            } else {
              debugPrint("FCM token registration returned unexpected state: $res");
            }
          }

          // 5) Foreground message handler: show local notification and optionally update UI
          onMessageSub = FirebaseMessaging.onMessage.listen((message) {
            debugPrint('Dashboard - onMessage: ${message.messageId}');
            showLocalNotification(message);
          });

          // 6) Token refresh: re-register token for stored user
          tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            debugPrint('Dashboard - token refreshed: $newToken');

            final currentStored = await LocalStorageService().getUser();
            if (currentStored == null) {
              debugPrint('No stored user when token refreshed - skipping registration.');
              return;
            }

            final ApiState<UserDataModel> refreshRes =
            await fcmService.registerToken(userId: currentStored.userId, token: newToken);

            if (refreshRes is ApiData<UserDataModel>) {
              await LocalStorageService().saveUser(refreshRes.data);
              debugPrint('FCM Token Refreshed and saved successfully (id=${refreshRes.data.userId})');
            } else if (refreshRes is ApiError<UserDataModel>) {
              debugPrint('FCM refresh registration failed: ${refreshRes.message}');
            } else {
              debugPrint('FCM refresh returned unexpected state: $refreshRes');
            }
          });

          // 7) Handle taps when app in background -> user opens app
          openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
            debugPrint('Dashboard - onMessageOpenedApp: ${message.messageId}');
          });

          // 8) If app was launched from terminated state by a notification
          final initialMessage = await messaging.getInitialMessage();
          if (initialMessage != null) {
            debugPrint('Dashboard - initialMessage: ${initialMessage.messageId}');
          }
        } catch (e) {
          debugPrint('Dashboard FCM init error: $e');
        }
      }();

      // cleanup
      return () {
        onMessageSub?.cancel();
        tokenRefreshSub?.cancel();
        openedAppSub?.cancel();
      };
    }, const []); // run once on mount

    // Static status steps
    final steps = Constants.statuses.where((s) => (s != 'Created' && s != 'Rejected')).toList();

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

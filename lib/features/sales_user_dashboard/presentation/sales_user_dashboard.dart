// lib/features/dashboard/presentation/sales_user_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/features/dashboard/presentation/stats_card.dart';
import 'package:microsensors/features/sales_user_dashboard/presentation/orders_card.dart';
import 'package:microsensors/services/fcm_service.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/colors.dart';
import '../../../core/local_storage_service.dart';
import '../repository/sales_dashboard_repository.dart';
import '../../../models/orders/order_models.dart';

class SalesUserDashboard extends HookWidget {
  const SalesUserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final fcmService = useMemoized(() => FcmService());
    final repo = useMemoized(() => SalesDashboardRepository());

    // user + preview states
    final salesUser = useState<UserDataModel?>(null);
    final loadingUser = useState<bool>(true);

    final items = useState<List<OrderListItem>>([]);
    final loadingPreview = useState<bool>(false);
    final previewError = useState<String?>(null);

    // ---- load stored user and init FCM (runs once) ----
    useEffect(() {
      StreamSubscription<RemoteMessage>? onMessageSub;
      StreamSubscription<String>? tokenRefreshSub;
      StreamSubscription<RemoteMessage>? openedAppSub;

      final FlutterLocalNotificationsPlugin localNotifications =
          FlutterLocalNotificationsPlugin();
      const AndroidNotificationChannel androidChannel =
          AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
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

      // async bootstrap
      () async {
        try {
          // Load stored user
          final storedUser = await LocalStorageService().getUser();
          salesUser.value = storedUser;
          loadingUser.value = false;

          // after we know user, attempt loading preview (if user exists)
          if (storedUser != null) {
            // load preview items (calls repo)
            await _loadPreviewForUser(
              repo,
              storedUser.userId,
              items,
              loadingPreview,
              previewError,
            );
          }

          // initialize local notifications plugin
          const androidInit = AndroidInitializationSettings(
            '@mipmap/ic_launcher',
          );
          final initSettings = InitializationSettings(android: androidInit);
          await localNotifications.initialize(initSettings);

          // request permissions
          final messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );

          // get token and register
          final token = await messaging.getToken();
          if (storedUser != null && token != null) {
            final ApiState<UserDataModel> res = await fcmService.registerToken(
              userId: storedUser.userId,
              token: token,
            );
            if (res is ApiData<UserDataModel>) {
              await LocalStorageService().saveUser(res.data);
              salesUser.value = res.data;
            } else {
              // ignore errors for now; logs would help
            }
          }

          // listeners
          onMessageSub = FirebaseMessaging.onMessage.listen((message) {
            showLocalNotification(message);
          });

          tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
            newToken,
          ) async {
            final currentStored = await LocalStorageService().getUser();
            if (currentStored != null) {
              final ApiState<UserDataModel> refreshRes = await fcmService
                  .registerToken(userId: currentStored.userId, token: newToken);
              if (refreshRes is ApiData<UserDataModel>) {
                await LocalStorageService().saveUser(refreshRes.data);
                salesUser.value = refreshRes.data;
              }
            }
          });

          openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
            // handle navigation from notification if needed
          });

          final initialMessage = await messaging.getInitialMessage();
          if (initialMessage != null) {
            // launched from notification
          }
        } catch (e) {
          loadingUser.value = false;
          debugPrint('Dashboard FCM/init error: $e');
        }
      }();

      return () {
        onMessageSub?.cancel();
        tokenRefreshSub?.cancel();
        openedAppSub?.cancel();
      };
    }, const []);

    // ---- helper to reload preview manually ----
    Future<void> reloadPreview() async {
      if (salesUser.value == null) {
        previewError.value = 'No user available';
        return;
      }
      await _loadPreviewForUser(
        repo,
        salesUser.value!.userId,
        items,
        loadingPreview,
        previewError,
      );
    }

    return Scaffold(
      body: Scrollbar(
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats header
              Text(
                "Stats",
                style: TextStyle(
                  color: AppColors.headingTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatsCard(
                      title: "Active Orders",
                      value: "--",
                      icon: Icons.play_for_work,
                      color: Colors.green,
                      width: 180,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "In Production",
                      value: "--",
                      icon: Icons.factory,
                      color: Colors.blue,
                      width: 180,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Dispatched",
                      value: "--",
                      icon: Icons.double_arrow,
                      color: Colors.purple,
                      width: 180,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Recent Orders:",
                      style: TextStyle(
                        color: AppColors.headingTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // navigate to full orders page
                      // context.push('/orders');
                    },
                    child: Text('See All'),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: reloadPreview,
                  ),
                ],
              ),

              // --- user loader ---
              if (loadingUser.value)
                SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                // Card containing preview area
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      // preview content: loading / error / empty (Add Order) / list
                      if (loadingPreview.value)
                        SizedBox(
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (previewError.value != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              Text(
                                'Failed to load orders',
                                style: TextStyle(color: Colors.red),
                              ),
                              SizedBox(height: 8),
                              Text(
                                previewError.value!,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: reloadPreview,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (items.value.isEmpty)
                        // EMPTY -> show Add Order CTA
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.add,
                                    size: 48,
                                    color: AppColors.appBlueColor,
                                  ),
                                  onPressed: () {
                                    context.push("/add-orders");
                                  },
                                ),
                                Text(
                                  "Create an order",
                                  style: TextStyle(
                                    color: AppColors.appBlueColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            // cards
                            ...items.value.map(
                              (o) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: OrderCardWidget(context, o),
                              ),
                            ),

                            // show "See more" when preview is full (i.e. 4 items)
                            if (items.value.length >= 4)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 8,
                                ),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                      ),
                                    ),
                                    icon: Icon(Icons.chevron_right),
                                    label: Text('See more'),
                                    onPressed: () {
                                      // navigate to full orders page — adjust route if different
                                      context.push(
                                        '/sales-orders-list',
                                      ); // or Navigator.pushNamed(context, '/orders');
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColors.fabForegroundIconColor,
        overlayOpacity: 0,
        spacing: 10,
        children: [
          SpeedDialChild(
            child: Icon(
              Icons.add_box,
              size: 28,
              color: AppColors.fabForegroundIconColor,
            ),
            label: "Create Order",
            labelStyle: TextStyle(color: AppColors.headingTextColor),
            backgroundColor: Colors.green,
            onTap: () {
              context.push("/add-orders");
            },
          ),
        ],
      ),
    );
  }
}

/// Loads preview items via repo and updates the provided states.
/// Kept outside the widget to keep build() tidy.
Future<void> _loadPreviewForUser(
  SalesDashboardRepository repo,
  int userId,
  ValueNotifier<List<OrderListItem>> items,
  ValueNotifier<bool> loading,
  ValueNotifier<String?> error,
) async {
  loading.value = true;
  error.value = null;
  try {
    final res = await repo.fetchOrders(salesId: userId, page: 0, size: 10);
    if (res is ApiData<PagedResponse<OrderListItem>>) {
      items.value = res.data.data.take(4).toList();
    } else if (res is ApiError<PagedResponse<OrderListItem>>) {
      error.value = res.message ?? 'API error';
      items.value = [];
    } else {
      error.value = 'Unexpected API state';
      items.value = [];
    }
  } catch (e) {
    error.value = e.toString();
    items.value = [];
  } finally {
    loading.value = false;
  }
}


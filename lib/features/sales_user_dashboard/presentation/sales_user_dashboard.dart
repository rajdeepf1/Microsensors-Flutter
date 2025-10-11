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
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../models/orders/sales_order_stats.dart';
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

    final items = useState<List<OrderResponseModel>>([]);
    final loadingPreview = useState<bool>(false);
    final previewError = useState<String?>(null);
    // NEW: total count from server for preview (used to decide "See more")
    final previewTotal = useState<int?>(null);

    // for stats
    final statsState = useState<OrderStats?>(null);
    final loadingStats = useState<bool>(true);
    final statsError = useState<String?>(null);

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
          salesUser.value = storedUser;
          loadingUser.value = false;
          if (storedUser != null) {
            // load preview items
            await _loadPreviewForUser(
            repo,
            storedUser.userId,
            items,
            loadingPreview,
            previewError,
            previewTotal,
            );

            // await _loadStatsForUser(
            // repo,
            // salesUser.value!.userId,
            // statsState,
            // loadingStats,
            // statsError,
            // context,
            // );
          }

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

    // ---- helper to reload preview + stats manually ----
    Future<void> reloadAll() async {
      if (salesUser.value == null) {
        previewError.value = 'No user available';
        return;
      }
      debugPrint("Called");
      await _loadPreviewForUser(
        repo,
        salesUser.value!.userId,
        items,
        loadingPreview,
        previewError,
        previewTotal,
      );
      // await _loadStatsForUser(
      //   repo,
      //   salesUser.value!.userId,
      //   statsState,
      //   loadingStats,
      //   statsError,
      //   context,
      // );
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
                      value: loadingStats.value
                          ? "..."
                          : (statsState.value != null ? statsState.value!.active.toString() : "--"),
                      icon: Icons.play_for_work,
                      color: Colors.green,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "In Production",
                      value: loadingStats.value
                          ? "..."
                          : (statsState.value != null ? statsState.value!.inProduction.toString() : "--"),
                      icon: Icons.factory,
                      color: Colors.blue,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Dispatched",
                      value: loadingStats.value
                          ? "..."
                          : (statsState.value != null ? statsState.value!.dispatched.toString() : "--"),
                      icon: Icons.double_arrow,
                      color: Colors.purple,
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
                      context.push('/sales-orders-list');
                    },
                    child: const Text('See All'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: "Refresh",
                    onPressed: reloadAll,
                  ),
                ],
              ),

              // --- user loader ---
              if (loadingUser.value)
                const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      if (loadingPreview.value)
                        const SizedBox(
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (previewError.value != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Failed to load orders',
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                previewError.value!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: reloadAll,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (items.value.isEmpty)
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
                              ...items.value.map(
                                    (o) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: orderCardWidget(context, o),
                                ),
                              ),
                              if ((previewTotal.value ?? items.value.length) > items.value.length)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      icon: const Icon(Icons.chevron_right),
                                      label: const Text('See more'),
                                      onPressed: () {
                                        context.push('/sales-orders-list');
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
              //context.push("/add-orders");
              context.push("/add-orders").then((result) {
                if (result == true) {
                  reloadAll();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Loads preview items via repo and updates the provided states.
/// Requests only 4 items from the API to keep the preview lightweight.
Future<void> _loadPreviewForUser(
    SalesDashboardRepository repo,
    int userId,
    ValueNotifier<List<OrderResponseModel>> items,
    ValueNotifier<bool> loading,
    ValueNotifier<String?> error,
    ValueNotifier<int?> previewTotal,
    ) async {
  loading.value = true;
  error.value = null;
  try {
    final res = await repo.fetchOrders(userId: userId, page: 0, size: 4);

    if (res is ApiData<PagedResponse<OrderResponseModel>>) {
      final fetched = res.data.data ?? <OrderResponseModel>[];
      // ensure we never show more than 4 items
      items.value = (fetched.length <= 4) ? fetched.toList() : fetched.take(4).toList();

      // defensive: try to read res.data.total, fallback to fetched.length
      try {
        final totalFromServer = res.data.total;
        previewTotal.value = (totalFromServer != null) ? totalFromServer : fetched.length;
      } catch (_) {
        previewTotal.value = fetched.length;
      }
    } else if (res is ApiError<PagedResponse<OrderResponseModel>>) {
      final msg = (res.message ?? '').toLowerCase();

      // treat common "no data / not found" messages as benign — don't set previewError
      final isBenign =
          msg.contains('not found') || msg.contains('no data') || msg.contains('no items') || msg.contains('404');

      if (isBenign) {
        // no items available — show empty preview without an error card
        items.value = [];
        previewTotal.value = 0;
        error.value = null; // keep UI quiet
        debugPrint('Preview: benign empty response for userId=$userId: "${res.message}"');
      } else {
        // real error — surface it in the preview area
        error.value = res.message;
        items.value = [];
        previewTotal.value = 0;
        debugPrint('Preview API error for userId=$userId: ${res.message}');
      }
    } else {
      error.value = 'Unexpected API state';
      items.value = [];
      previewTotal.value = 0;
      debugPrint('Preview unexpected API state for userId=$userId: $res');
    }
  } catch (e, st) {
    error.value = e.toString();
    items.value = [];
    previewTotal.value = 0;
    debugPrint('Preview load exception for userId=$userId: $e\n$st');
  } finally {
    loading.value = false;
  }
}

/// Loads stats for the given user id and updates provided state notifiers.
Future<void> _loadStatsForUser(
    SalesDashboardRepository repo,
    int userId,
    ValueNotifier<OrderStats?> statsState,
    ValueNotifier<bool> loadingStats,
    ValueNotifier<String?> statsError,
    BuildContext ctx,
    ) async {
  loadingStats.value = true;
  statsError.value = null;
  try {
    final res = await repo.fetchOrderStats(salesId: userId);
    if (res is ApiData<OrderStats>) {
      statsState.value = res.data;
    } else if (res is ApiError<OrderStats>) {
      statsError.value = res.message;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(statsError.value!)),
      );
    } else {
      statsError.value = 'Unexpected response';
    }
  } catch (e, st) {
    statsError.value = 'Error loading stats';
    debugPrint('Stats load error: $e\n$st');
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Failed to load stats')),
    );
  } finally {
    loadingStats.value = false;
  }
}

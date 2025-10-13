// === FILE: lib/features/dashboard/presentation/dashboard.dart ===
import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/features/dashboard/presentation/stats_card.dart';
import 'package:microsensors/services/fcm_service.dart';
import '../../../models/orders/order_status_count_model.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/colors.dart';
import '../repository/dashboard_repository.dart';
import 'products_lottie_card.dart';
import 'users_lottie_card.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:microsensors/core/local_storage_service.dart';

class Dashboard extends HookWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => DashboardRepository());
    final fcmService = useMemoized(() => FcmService());

    final usersState = useState<ApiState<List<UserDataModel>>>(const ApiInitial());
    final productsState = useState<ApiState<List<ProductDataModel>>>(const ApiInitial());
    final orderStatusCountState = useState<ApiState<OrderStatusCountModel>>(const ApiInitial());

    final loading = useState<bool>(false);
    final error = useState<String?>(null);
    var countModel = useState<OrderStatusCountModel?>(null);

    Future<void> loadOrderCounts() async {
      loading.value = true;
      error.value = null;

      try {
        final storedUser = await LocalStorageService().getUser();
        final role = storedUser?.roleName.toUpperCase() ?? 'ADMIN'; // fallback

        orderStatusCountState.value = const ApiLoading();
        final result = await repo.fetchOrdersCountByStatus(role: role);
        orderStatusCountState.value = result;

        if (result is ApiData<OrderStatusCountModel>) {
          countModel.value = result.data;
        } else {
          countModel.value = null;
        }
      } catch (e, st) {
        orderStatusCountState.value = ApiError('Error: $e', error: e, stackTrace: st);
        countModel.value = null;
      } finally {
        loading.value = false;
      }
    }

    Future<void> loadAll() async {
      usersState.value = const ApiLoading();
      productsState.value = const ApiLoading();

      usersState.value = await repo.fetchUsers();
      productsState.value = await repo.fetchProducts();

      await loadOrderCounts();
    }




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

          // NOTE: DO NOT initialize localNotifications here. It is initialized once in main.dart.

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

    // existing loadAll effect
    useEffect(() {
      loadAll();
      return null;
    }, []);

    return Scaffold(
      body: Scrollbar(
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Stats",
                style: TextStyle(
                    color: AppColors.headingTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

              // Horizontal scroll stats cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatsCard(
                      title: "Orders",
                      value: countModel.value?.total.toString() ?? "-",
                      icon: Icons.shopping_cart,
                      color: Colors.green,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Users",
                      value: _stateToString(usersState.value),
                      icon: Icons.person,
                      color: Colors.blue,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Products",
                      value: _stateToString(productsState.value),
                      icon: Icons.inventory,
                      color: Colors.purple,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Text(
                "Users",
                style: TextStyle(
                    color: AppColors.headingTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              UsersLottieCard(
                lottiePath: "assets/animations/adduser.json",
                icon: Icons.person_pin_outlined,
                label: "Users",
                onTap: () {
                  context.push("/users");
                },
              ),

              const SizedBox(height: 20),

              Text(
                "Products",
                style: TextStyle(
                    color: AppColors.headingTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              ProductsLottieCard(
                lottiePath: "assets/animations/addproduct.json",
                icon: Icons.file_copy_outlined,
                label: "Products",
                onTap: () {
                  context.push("/products");
                },
              ),

              const SizedBox(height: 20),

              Text(
                "Order Activities",
                style: TextStyle(
                    color: AppColors.headingTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

              ProductsLottieCard(
                lottiePath: "assets/animations/orderactivity.json",
                icon: Icons.shopping_cart,
                label: "Activities",
                onTap: () {
                  context.push("/order-activities");
                },
              ),

              SizedBox(height: 50,)

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
            child: Icon(Icons.person_add,
                size: 28, color: AppColors.fabForegroundIconColor),
            label: "Add User",
            labelStyle: TextStyle(color: AppColors.headingTextColor),
            backgroundColor: Colors.blue,
            onTap: () {
              context.push("/add-user");
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.add_box,
                size: 28, color: AppColors.fabForegroundIconColor),
            label: "Add Product",
            labelStyle: TextStyle(color: AppColors.headingTextColor),
            backgroundColor: Colors.green,
            onTap: () {
              context.push("/add-product");
            },
          ),
        ],
      ),
    );
  }

  String _stateToString(ApiState<List<dynamic>> state) {
    if (state is ApiInitial) return "-";
    if (state is ApiLoading) return "...";
    if (state is ApiError) return "!";
    if (state is ApiData<List<dynamic>>) return state.data.length.toString();
    return "-";
  }
}

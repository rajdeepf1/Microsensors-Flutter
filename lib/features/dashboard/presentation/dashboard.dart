// lib/features/dashboard/presentation/dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/features/dashboard/presentation/stats_card.dart';
import 'package:microsensors/services/fcm_service.dart';
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

    // load both counts
    Future<void> loadAll() async {
      usersState.value = const ApiLoading();
      productsState.value = const ApiLoading();

      usersState.value = await repo.fetchUsers();
      productsState.value = await repo.fetchProducts();
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
      Future<void> _showLocalNotification(RemoteMessage message) async {
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

      // start async block
      () async {
        try {
          // 1) Load stored user
          final storedUser = await LocalStorageService().getUser();

          // 2) initialize the local plugin (safe to call even if main already created channel)
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          final initSettings = InitializationSettings(android: androidInit);
          await localNotifications.initialize(initSettings);

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
            // call your registerToken which returns ApiState<UserDataModel>
            final ApiState<UserDataModel> res =
                await fcmService.registerToken(userId: storedUser.userId, token: token);

            if (res is ApiData<UserDataModel>) {
              // success - backend returned canonical user object in data
              final UserDataModel savedUser = res.data;
              await LocalStorageService().saveUser(savedUser);
              debugPrint("FCM token saved successfully and stored user updated (id=${savedUser.userId})");
            } else if (res is ApiError<UserDataModel>) {
              // server returned an error state
              debugPrint("FCM token registration failed: ${res.message}");
            } else {
              // defensive: unexpected state
              debugPrint("FCM token registration returned unexpected state: $res");
            }
          }

          // 5) Foreground message handler: show local notification and optionally update UI
          onMessageSub = FirebaseMessaging.onMessage.listen((message) {
            debugPrint('Dashboard - onMessage: ${message.messageId}');
            _showLocalNotification(message);
          });

          // 6) Token refresh: re-register token for stored user
          tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            debugPrint('Dashboard - token refreshed: $newToken');

            // handle nulls defensively
            final currentStored = await LocalStorageService().getUser();
            if (currentStored == null) {
              debugPrint('No stored user when token refreshed - skipping registration.');
              return;
            }
            if (newToken == null) {
              debugPrint('Refreshed token is null - skipping registration.');
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
                    color: AppColors.heading_text_color,
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
                      value: "--",
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
                    color: AppColors.heading_text_color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              UsersLottieCard(
                lottiePath: "assets/animations/adduser.json",
                icon: Icons.person_pin_outlined,
                label: "Users",
                onTap: () {
                  print("Users Clicked");
                  context.push("/users");
                },
              ),

              const SizedBox(height: 20),

              Text(
                "Products",
                style: TextStyle(
                    color: AppColors.heading_text_color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              ProductsLottieCard(
                lottiePath: "assets/animations/addproduct.json",
                icon: Icons.file_copy_outlined,
                label: "Products",
                onTap: () {
                  print("Add Product Clicked");
                  context.push("/products");
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColors.fab_foreground_icon_color,
        overlayOpacity: 0,
        spacing: 10,
        children: [
          SpeedDialChild(
            child: Icon(Icons.person_add,
                size: 28, color: AppColors.fab_foreground_icon_color),
            label: "Add User",
            labelStyle: TextStyle(color: AppColors.heading_text_color),
            backgroundColor: Colors.blue,
            onTap: () {
              print("Add User Clicked");
              context.push("/add-user");
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.add_box,
                size: 28, color: AppColors.fab_foreground_icon_color),
            label: "Add Product",
            labelStyle: TextStyle(color: AppColors.heading_text_color),
            backgroundColor: Colors.green,
            onTap: () {
              print("Add Product Clicked");
              context.push("/add-product");
            },
          ),
        ],
      ),
    );
  }

  String _state_toString_helper(ApiState<List<dynamic>> state) => _stateToString(state);

  String _stateToString(ApiState<List<dynamic>> state) {
    if (state is ApiInitial) return "-";
    if (state is ApiLoading) return "...";
    if (state is ApiError) return "!";
    if (state is ApiData<List<dynamic>>) return state.data.length.toString();
    return "-";
  }
}

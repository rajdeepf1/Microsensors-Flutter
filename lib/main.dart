import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:microsensors/utils/colors.dart';
import 'core/router_provider.dart';

//
// ---------------------- TOP-LEVEL BACKGROUND HANDLERS (must be top-level) ----------------------
//

// Called when a Firebase message is received in background/terminated state.
// Must be a top-level or static function and is an entrypoint for the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM BG message received: ${message.messageId}');
  // TODO: process message, store in DB, etc.
}

// Must be a top-level function (entry point) for flutter_local_notifications background callback.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Called when user taps a notification while app is terminated and handled by the
  // flutter_local_notifications plugin background entrypoint.
  debugPrint(
      'notificationTapBackground — id: ${response.id}, actionId: ${response.actionId}, payload: ${response.payload}');
  // Note: do not use async/await here. If you need to schedule work, use platform channels or a background isolate.
}

//
// ---------------------- LOCAL NOTIFICATIONS SETUP ----------------------
//

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

Future<void> _initLocalNotifications() async {
  const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  final initSettings = InitializationSettings(
    android: androidInitSettings,
    // If you add iOS support in the future, include iOS settings here.
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // App is in foreground or background (not terminated) and user tapped the notification.
      debugPrint(
          'onDidReceiveNotificationResponse — id: ${response.id}, actionId: ${response.actionId}, payload: ${response.payload}');
      // TODO: navigate within app or handle payload. Use your router/provider to navigate.
    },
    // This must be a top-level function (we defined `notificationTapBackground` above)
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Create channel on Android 8+
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final android = message.notification?.android;

  if (notification == null) return;

  // If android metadata exists, show local notification (for foreground)
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      icon: '@mipmap/ic_launcher', // change to your notification icon if you added one
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    details,
    payload: message.data.isNotEmpty ? message.data.toString() : null,
  );
}

//
// ---------------------- FCM SETUP (one-time, top-level call before runApp) ----------------------
//

Future<void> _setupFirebaseMessaging() async {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Request permission (iOS and Android 13+)
  final settings = await _messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  debugPrint('FCM permission status: ${settings.authorizationStatus}');

  // Get FCM token
  final token = await _messaging.getToken();
  debugPrint('FCM Token: $token');
  // TODO: send token to your server

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    debugPrint('FCM Token refreshed: $newToken');
    // TODO: send refreshed token to server
  });

  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.messageId}');
    // Show a local notification for a notification payload
    _showLocalNotification(message);
    // You can also handle data-only messages here
  });

  // When the user taps a notification and opens the app from background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
    // TODO: navigate to a screen based on message.data or notification
  });

  // If the app was opened from terminated state by a notification
  final initialMessage = await _messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('FCM initial message: ${initialMessage.messageId}');
    // TODO: handle navigation
  }
}

//
// ---------------------- MAIN ----------------------
//

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    // If you used FlutterFire CLI, pass options here:
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications (channels, handlers)
  await _initLocalNotifications();

  // Register Firebase background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Setup messaging listeners and permissions (one-time)
  await _setupFirebaseMessaging();

  runApp(const ProviderScope(child: MyApp()));
}

//
// ---------------------- App Widget (unchanged router usage) ----------------------
//

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider); // 👈 Watch router

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.app_blue_color,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
    );
  }
}

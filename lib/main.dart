// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// optional, still available
import 'package:microsensors/utils/colors.dart';
import 'core/router_provider.dart';
//import 'package:microsensors/services/socket_service.dart';
//
// ---------------------- TOP-LEVEL BACKGROUND HANDLERS (must be top-level) ----------------------
//

// For web
const firebaseWebOptions = FirebaseOptions(

    apiKey: "AIzaSyCqDvbxxD1TkrVheYmZUERRzi_wX7B4atA",

    authDomain: "microsensors-a8c89.firebaseapp.com",

    projectId: "microsensors-a8c89",

    storageBucket: "microsensors-a8c89.firebasestorage.app",

    messagingSenderId: "559971445474",

    appId: "1:559971445474:web:d90e9b5b7e8206299b4cbb",

    measurementId: "G-76V23TRR12"

);

// Called when a Firebase message is received in background/terminated state.
// Must be a top-level or static function and is an entrypoint for the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  //await Firebase.initializeApp(options: firebaseWebOptions);
  debugPrint('FCM BG message received: ${message.messageId}');
  // TODO: lightweight processing (store payload, analytics, etc.)
}

// Must be a top-level function (entry point) for flutter_local_notifications background callback.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
      'notificationTapBackground — id: ${response.id}, actionId: ${response.actionId}, payload: ${response.payload}');
  // Keep this function lightweight and non-async.
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
    // add iOS settings when you need iOS support
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint(
          'onDidReceiveNotificationResponse — id: ${response.id}, actionId: ${response.actionId}, payload: ${response.payload}');
      // TODO: navigate in-app based on payload (use router/provider)
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Create channel on Android 8+
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

/// Helper to show a local notification (main keeps it so we can reuse in other places)
Future<void> showLocalNotificationFromMessage(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      icon: '@mipmap/ic_launcher',
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
// ---------------------- MAIN (keep initialization + background handlers) ----------------------
//



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    // If you used FlutterFire CLI, pass options here:
     //options: firebaseWebOptions,
  );

  // Initialize local notifications (channels, handlers)
  await _initLocalNotifications();

  // Register Firebase background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // IMPORTANT: Do NOT add foreground listeners here if you intend to run them in Dashboard.
  // We'll set up permission, getToken, and foreground listeners in Dashboard so they are active only when user reaches that screen.

  runApp(const ProviderScope(child: MyApp()));
}

//
// ---------------------- APP WIDGET ----------------------
//

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    /**********************web sockets****************************************/
//     // connect and auto-subscribe to /topic/user_{userId}
//     SimpleSocketService.instance.connect(
//       userId: 1,
//       urlOverride: 'ws://10.0.2.2:8080/ws', // use wss in prod
//       reconnectMs: 3000,
//     );
//
// // listen to incoming messages
//     SimpleSocketService.instance.messages.listen((payload) {
//       print('Realtime payload: $payload');
//       // update providers/state or show in-app banner
//     });
//
//     SimpleSocketService.instance.subscribe(destination: '/topic/orders_101', id: 'sub-order-101');
//     SimpleSocketService.instance.sendJson('/app/orders/command', {'cmd':'ack','orderId':101});


    //SimpleSocketService.instance.disconnect();
    /**********************web sockets****************************************/

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.appBlueColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
    );
  }
}

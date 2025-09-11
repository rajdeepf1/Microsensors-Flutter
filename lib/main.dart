import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:microsensors/services/socket_service.dart';
import 'services/fcm_service.dart'; // our new service
import 'package:microsensors/utils/colors.dart';
import 'core/router_provider.dart';

//
// ---------------------- TOP-LEVEL BACKGROUND HANDLERS ----------------------
//

// Background FCM handler: runs when message received in background/terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM BG message received: ${message.messageId}');
}

// Notification tap handler (terminated state, handled by flutter_local_notifications)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
      'notificationTapBackground — id: ${response.id}, actionId: ${response.actionId}, payload: ${response.payload}');
}

//
// ---------------------- MAIN ----------------------
//

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register background FCM handler (must be before runApp)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize FCM service (local notifications + foreground handlers)
  await FcmService.instance.init(
    backendBase: 'https://your-backend.example.com', // 🔑 change this
  );

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
          backgroundColor: AppColors.app_blue_color,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
    );
  }
}
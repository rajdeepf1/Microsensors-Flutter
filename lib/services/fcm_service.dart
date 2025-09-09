// lib/services/fcm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

/// FcmService
/// - init() sets up local notifications & foreground message handling
/// - registerTokenForUser(userId) POSTs the device token to your backend
/// - messages is a broadcast stream of incoming payloads (Map<String,dynamic>)
class FcmService {
  FcmService._private();
  static final FcmService instance = FcmService._private();

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // broadcast stream for app to listen to incoming payloads
  final StreamController<Map<String, dynamic>> _messagesController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  // Android notification channel
  static const AndroidNotificationChannel _androidChannel =
  AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  String backendBaseUrl = ''; // set via init or leave and pass in registerTokenForUser

  /// Initialize FCM handling and local notifications.
  /// Call this once early (e.g., in main before runApp).
  Future<void> init({String? backendBase}) async {
    if (backendBase != null) backendBaseUrl = backendBase;

    // initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings();
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(settings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Local notification tapped (payload): ${response.payload}');
          // UI should react to payload (listen to messages stream or handle navigation separately)
        });

    // create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // request permissions (iOS / Android 13+)
    await FirebaseMessaging.instance.requestPermission();

    // foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      debugPrint('FCM onMessage: ${msg.messageId}');
      _handleRemoteMessage(msg);
    });

    // token refresh - you may want to register the refreshed token again after login
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
      // Optionally: if you store current logged-in userId globally, re-register here
    });

    // Note: background handler must be top-level and registered in main.dart:
    // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Register current device token for a given user on your backend.
  /// Call this after successful login (pass the numeric userId).
  Future<bool> registerTokenForUser(int userId, {String? backendBase}) async {
    if (backendBase != null) backendBaseUrl = backendBase;
    if (backendBaseUrl.isEmpty) {
      debugPrint('FcmService: backendBaseUrl not set; cannot register token.');
      return false;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('FcmService: token is null');
        return false;
      }

      final uri = Uri.parse(
          '$backendBaseUrl/api/device/token?userId=$userId&token=${Uri.encodeComponent(token)}');

      final resp = await http.post(uri);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        debugPrint('FcmService: token registered for user $userId');
        return true;
      } else {
        debugPrint(
            'FcmService: failed to register token: ${resp.statusCode} ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('FcmService: register token error: $e');
      return false;
    }
  }

  /// Return current device FCM token (useful for debugging)
  Future<String?> getDeviceToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  void _handleRemoteMessage(RemoteMessage msg) {
    // prefer data payload
    Map<String, dynamic> payload = <String, dynamic>{};
    if (msg.data.isNotEmpty) {
      payload = Map<String, dynamic>.from(msg.data);
    } else if (msg.notification != null) {
      payload = {
        'type': 'NOTIFICATION',
        'title': msg.notification!.title ?? '',
        'body': msg.notification!.body ?? '',
      };
    }

    // send to app-level stream
    _messagesController.add(payload);

    // show a local notification (so foreground behaves like background)
    _showLocalNotification(payload);
  }

  Future<void> _showLocalNotification(Map<String, dynamic> payload) async {
    final title = payload['title']?.toString() ?? payload['type']?.toString() ?? 'Notification';
    final body = payload['body']?.toString() ?? '';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: jsonEncode(payload),
    );
  }

  /// Clean up
  Future<void> dispose() async {
    await _messagesController.close();
  }
}

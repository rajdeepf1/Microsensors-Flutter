// lib/services/socket_service_simple.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart';

/// SimpleSocketService
///
/// - Minimal STOMP-over-WebSocket client (no external STOMP package)
/// - Connects to a raw websocket endpoint and speaks basic STOMP frames:
///     CONNECT, SUBSCRIBE, MESSAGE parsing
/// - Emits parsed JSON MESSAGE bodies to [messages]
/// - Provides helpers: subscribe(destination), send(frame), disconnect()
///
/// NOTES:
/// - Server must accept raw STOMP frames over WebSocket (Spring's STOMP endpoint without SockJS).
/// - In production use wss:// and ensure Nginx proxies Upgrade headers.
class SimpleSocketService {
  SimpleSocketService._private();
  static final SimpleSocketService instance = SimpleSocketService._private();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _messagesController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  String websocketUrl = 'ws://10.0.2.2:8080/ws';
  bool _connected = false;
  bool _intentionalDisconnect = false;
  int reconnectDelayMs = 3000;

  /// Public getter
  bool get isConnected => _connected;

  /// Connect and auto-subscribe to /topic/user_{userId}
  void connect({required int userId, String? urlOverride, int? reconnectMs}) {
    if (_connected) return;
    if (urlOverride != null && urlOverride.isNotEmpty) websocketUrl = urlOverride;
    if (reconnectMs != null) reconnectDelayMs = reconnectMs;
    _intentionalDisconnect = false;
    _tryOpen(userId);
  }

  void _tryOpen(int userId) {
    debugPrint('WS: connecting to $websocketUrl');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));
      _connected = true;

      // Send STOMP CONNECT
      _channel!.sink.add('CONNECT\naccept-version:1.2\nheart-beat:10000,10000\n\n\u0000');

      // Listen raw frames
      _sub = _channel!.stream.listen((dynamic raw) {
        if (raw == null) return;
        final String s = raw.toString();
        debugPrint('WS RAW: $s');

        // CONNECTED frame -> subscribe to user topic
        if (s.startsWith('CONNECTED')) {
          debugPrint('STOMP connected, subscribing to /topic/user_$userId');
          final subFrame =
              'SUBSCRIBE\nid:sub-user-$userId\ndestination:/topic/user_$userId\n\n\u0000';
          _channel!.sink.add(subFrame);
          return;
        }

        // MESSAGE frame parsing
        if (s.startsWith('MESSAGE')) {
          // STOMP frames separate headers and body with an empty line (\n\n).
          // Some brokers append \u0000 at the end — remove safely.
          final parts = s.split('\n\n');
          if (parts.length >= 2) {
            final bodyAndTerm = parts.sublist(1).join('\n\n');
            final body = bodyAndTerm.replaceAll('\u0000', '').trim();
            if (body.isNotEmpty) {
              try {
                final parsed = jsonDecode(body);
                if (parsed is Map<String, dynamic>) {
                  _messagesController.add(parsed);
                } else {
                  // if server sends a non-object JSON (array/string), wrap it
                  _messagesController.add(<String, dynamic>{'payload': parsed});
                }
              } catch (e) {
                debugPrint('STOMP parse error: $e; body="$body"');
              }
            }
          } else {
            // fallback: try to extract after first blank line in a tolerant way
            final idx = s.indexOf('\n\n');
            if (idx >= 0 && idx + 2 < s.length) {
              final rawBody = s.substring(idx + 2).replaceAll('\u0000', '').trim();
              try {
                final parsed = jsonDecode(rawBody);
                if (parsed is Map<String, dynamic>) {
                  _messagesController.add(parsed);
                } else {
                  _messagesController.add(<String, dynamic>{'payload': parsed});
                }
              } catch (e) {
                debugPrint('STOMP fallback parse error: $e; body="$rawBody"');
              }
            }
          }
        }
      }, onDone: () {
        debugPrint('WS done. will reconnect in ${reconnectDelayMs}ms if not intentionally disconnected');
        _connected = false;
        _sub = null;
        _channel = null;
        if (!_intentionalDisconnect) {
          Future.delayed(Duration(milliseconds: reconnectDelayMs), () => _tryOpen(userId));
        }
      }, onError: (err) {
        debugPrint('WS error: $err');
        _connected = false;
        _sub = null;
        _channel = null;
        if (!_intentionalDisconnect) {
          Future.delayed(Duration(milliseconds: reconnectDelayMs), () => _tryOpen(userId));
        }
      }, cancelOnError: true);
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _connected = false;
      _sub = null;
      _channel = null;
      if (!_intentionalDisconnect) {
        Future.delayed(Duration(milliseconds: reconnectDelayMs), () => _tryOpen(userId));
      }
    }
  }

  /// Subscribe to arbitrary STOMP destination
  /// id should be unique per subscription (e.g. 'sub-order-123')
  void subscribe({required String destination, required String id}) {
    if (_channel == null) {
      debugPrint('subscribe: channel null; not connected');
      return;
    }
    final frame = 'SUBSCRIBE\nid:$id\ndestination:$destination\n\n\u0000';
    _channel!.sink.add(frame);
  }

  /// Unsubscribe by id
  void unsubscribe({required String id}) {
    if (_channel == null) return;
    final frame = 'UNSUBSCRIBE\nid:$id\n\n\u0000';
    _channel!.sink.add(frame);
  }

  /// Send a raw STOMP SEND frame to the destination with JSON body
  void sendJson(String destination, Map<String, dynamic> jsonBody) {
    final body = jsonEncode(jsonBody);
    final frame = 'SEND\ndestination:$destination\ncontent-type:application/json\ncontent-length:${body.length}\n\n$body\u0000';
    _channel?.sink.add(frame);
  }

  /// Low-level send: send arbitrary text frame
  void sendRaw(String frameText) {
    _channel?.sink.add(frameText);
  }

  /// Disconnect intentionally and stop reconnect attempts
  void disconnect() {
    _intentionalDisconnect = true;
    try {
      _sub?.cancel();
    } catch (_) {}
    try {
      _channel?.sink.close(status.normalClosure);
    } catch (_) {}
    _connected = false;
    _sub = null;
    _channel = null;
  }

  /// Cleanup resources
  void dispose() {
    _messagesController.close();
    disconnect();
  }
}

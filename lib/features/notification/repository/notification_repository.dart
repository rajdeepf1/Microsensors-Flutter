import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:microsensors/core/api_client.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/models/notification/notification_model.dart';

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository([ApiClient? client]) : _client = client ?? ApiClient();

  Future<ApiState<NotificationPageResult>> fetchNotificationsPage({
    required String role,
    required int? userId,
    required int page,
    required int size,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = {
        'role': role,
        'page': page,
        'size': size,
        if (userId != null) 'userId': userId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      };

      debugPrint("NotificationRepository params------>${params}");

      final response = await _client.get('notifications/list', queryParameters: params);

      if (response.statusCode != 200) {
        return ApiError('Server error: ${response.statusCode}');
      }

      final raw = response.data;
      if (raw is Map && raw['data'] is Map) {
        final payload = raw['data'] as Map<String, dynamic>;
        final itemsRaw = payload['items'];
        final total = payload['total'] is int ? payload['total'] as int : null;

        List<NotificationModel> items = [];
        if (itemsRaw is List) {
          items = itemsRaw
              .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        return ApiData(NotificationPageResult(items: items, total: total));
      } else {
        return const ApiError('Unexpected paged response format');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  Future<ApiState<String>> markAsRead({
    required int userId,
    List<int>? notificationIds,
  }) async {
    try {
      final queryParams = {
        'userId': userId,
        if (notificationIds != null && notificationIds.isNotEmpty)
          'notificationIds': notificationIds.join(','),
      };

      final response = await _client.get(
        'notifications/mark-read',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ApiData<String>(response.data['data'] ?? 'Notifications marked as read');
      }

      return ApiError('Failed to mark as read');
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  Future<ApiState<int>> getUnreadCount({required int userId}) async {
    try {
      final response = await _client.get(
        'notifications/unread-count',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final count = (data is int) ? data : 0;
        return ApiData(count);
      } else {
        return ApiError('Failed to fetch unread count');
      }
    } catch (e, st) {
      return ApiError('Error fetching unread count: $e', error: e, stackTrace: st);
    }
  }

  Future<ApiState<String>> deleteNotifications({
    required int userId,
    required List<int> notificationIds,
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'userId': userId,
        'notificationIds': notificationIds.join(','), // comma-separated IDs
      };

      debugPrint("DELETE notifications params -> $queryParams");

      // Use DELETE method from ApiClient
      final response = await _client.delete(
        'notifications/delete',
        queryParameters: queryParams,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint("DELETE notifications response -> ${response.data}");

      // Expected response: { "success": true, "data": "..." }
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        final message =
            response.data['data'] ?? 'Notifications deleted successfully';
        return ApiData<String>(message);
      }

      // Handle API structure mismatch
      return ApiError('Failed to delete notifications');
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }



}

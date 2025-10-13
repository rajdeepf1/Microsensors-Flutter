import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/order_status_count_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/product/product_list_response.dart';
// if needed

class DashboardRepository {
  final ApiClient _client;
  DashboardRepository([ApiClient? client]) : _client = client ?? ApiClient();

  Future<ApiState<List<UserDataModel>>> fetchUsers() async {
    try {
      final response = await _client.get('user/all-active-non-active');
      if (response.statusCode == 200) {
        final raw = response.data;
        // expected shape: { success: true, statusCode: 200, data: [ ... ], error: null }
        if (raw is Map && raw['data'] is List) {
          final list = (raw['data'] as List)
              .map((e) => UserDataModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return ApiData<List<UserDataModel>>(list);
        } else if (raw is List) {
          final list = raw.map((e) => UserDataModel.fromJson(Map<String, dynamic>.from(e))).toList();
          return ApiData<List<UserDataModel>>(list);
        } else {
          return const ApiError('Unexpected users response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr, st) {
      if (dioErr.type == DioExceptionType.connectionTimeout || dioErr.type == DioExceptionType.receiveTimeout) {
        return ApiError('Connection timed out', error: dioErr, stackTrace: st);
      } else if (dioErr.response != null) {
        final body = dioErr.response?.data;
        final msg = (body is Map && body['error'] != null) ? body['error'].toString() : 'Request failed';
        return ApiError(msg, error: dioErr, stackTrace: st);
      } else {
        return ApiError(dioErr.message ?? 'Network error', error: dioErr, stackTrace: st);
      }
    } catch (e, st) {
      return ApiError(e.toString(), error: e, stackTrace: st);
    }
  }

  Future<ApiState<List<ProductDataModel>>> fetchProducts() async {
    try {
      final response = await _client.get('products/all');
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map && raw['data'] is List) {
          final list = (raw['data'] as List)
              .map((e) => ProductDataModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return ApiData<List<ProductDataModel>>(list);
        } else if (raw is List) {
          final list = raw.map((e) => ProductDataModel.fromJson(Map<String, dynamic>.from(e))).toList();
          return ApiData<List<ProductDataModel>>(list);
        } else {
          return const ApiError('Unexpected products response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr, st) {
      if (dioErr.type == DioExceptionType.connectionTimeout || dioErr.type == DioExceptionType.receiveTimeout) {
        return ApiError('Connection timed out', error: dioErr, stackTrace: st);
      } else if (dioErr.response != null) {
        final body = dioErr.response?.data;
        final msg = (body is Map && body['error'] != null) ? body['error'].toString() : 'Request failed';
        return ApiError(msg, error: dioErr, stackTrace: st);
      } else {
        return ApiError(dioErr.message ?? 'Network error', error: dioErr, stackTrace: st);
      }
    } catch (e, st) {
      return ApiError(e.toString(), error: e, stackTrace: st);
    }
  }

  // order activities
  Future<ApiState<PagedResponse<OrderResponseModel>>> fetchOrders({
    String? status,
    int page = 0,
    int size = 20,
    String? q,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'size': size,
      };

      if (status != null && status.isNotEmpty) {
        params['status'] = status;
      }
      if (q != null && q.isNotEmpty) {
        params['search'] = q;
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        params['dateFrom'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        params['dateTo'] = dateTo;
      }

      debugPrint('GET orders/admin params: $params');

      final response = await _client.get(
        'orders/admin',
        queryParameters: params,
      );

      debugPrint("RESP status=${response.statusCode} data=${response.data}");

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final dataWrapper = raw['data'];
          if (dataWrapper is Map<String, dynamic>) {
            final paged = PagedResponse<OrderResponseModel>.fromJson(
              dataWrapper,
                  (m) => OrderResponseModel.fromJson(m),
            );
            return ApiData(paged);
          }
          return const ApiError('Invalid data format');
        }
        return const ApiError('Unexpected response format');
      }
      return ApiError('Server error: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && e.response!.data['error'] != null)
          ? e.response!.data['error'].toString()
          : e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


  /// Approve or reject an order (admin endpoint)
  Future<ApiState<String>> approveOrRejectOrder({
    required int orderId,
    required int adminId,
    required String action, // "APPROVE" or "REJECT"
    String? priority, // optional: "Low","Medium","High","Urgent"
    int? productionManagerId, // optional
  }) async {
    try {
      final body = <String, dynamic>{
        'adminId': adminId,
        'action': action,
      };
      if (priority != null) body['priority'] = priority;
      if (productionManagerId != null) body['productionManagerId'] = productionManagerId;

      final response = await _client.post(
        'orders/$orderId/approval',
        data: body,
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        // expected: { success:true, statusCode:200, data: "Order approved", error: null }
        if (raw is Map && raw['data'] is String) {
          return ApiData<String>(raw['data'] as String);
        } else if (raw is String) {
          // fallback
          return ApiData<String>(raw);
        } else {
          return const ApiError('Unexpected approval response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr) {
      final body = dioErr.response?.data;
      final msg = (body is Map && body['error'] != null) ? body['error'].toString() : (dioErr.message ?? 'Network error');
      return ApiError(msg, error: dioErr);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }




  // for count of total orders in the dashboard

  Future<ApiState<OrderStatusCountModel>> fetchOrdersCountByStatus({
    required String role,
    int? userId,
  }) async {
    try {
      final params = <String, dynamic>{
        'role': role,
        if (userId != null) 'userId': userId.toString(),
      };

      final response = await _client.get('orders/count', queryParameters: params);

      if (response.statusCode == 200) {
        final raw = response.data;

        if (raw is Map && raw['data'] is Map<String, dynamic>) {
          final model = OrderStatusCountModel.fromJson(
              Map<String, dynamic>.from(raw['data']));
          return ApiData<OrderStatusCountModel>(model);
        } else {
          return const ApiError('Unexpected count response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr, st) {
      if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
        return ApiError('Connection timed out', error: dioErr, stackTrace: st);
      } else if (dioErr.response != null) {
        final body = dioErr.response?.data;
        final msg = (body is Map && body['error'] != null)
            ? body['error'].toString()
            : 'Request failed';
        return ApiError(msg, error: dioErr, stackTrace: st);
      } else {
        return ApiError(dioErr.message ?? 'Network error',
            error: dioErr, stackTrace: st);
      }
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  /// Delete an order (Admin only)
  Future<ApiState<String>> deleteOrder({
    required int orderId,
    required int adminId,
  }) async {
    try {
      final response = await _client.delete(
        'orders/$orderId/delete',
        queryParameters: {'adminId': adminId},
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map && raw['data'] is String) {
          return ApiData<String>(raw['data'] as String);
        } else if (raw is String) {
          return ApiData<String>(raw);
        } else {
          return const ApiError('Unexpected delete response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr) {
      final body = dioErr.response?.data;
      final msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : (dioErr.message ?? 'Network error');
      return ApiError(msg, error: dioErr);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/production_manager_order_list.dart';
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

  Future<ApiState<PagedResponse<PmOrderListItem>>> fetchOrders({
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

      // add optional filters only when provided
      if (status != null && status.isNotEmpty) {
        params['status'] = status;
      }
      if (q != null && q.isNotEmpty) {
        params['q'] = q;
      }
      if (dateFrom != null && dateFrom.isNotEmpty) {
        params['dateFrom'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        params['dateTo'] = dateTo;
      }

      // debug: print final URI (handy while testing)
      debugPrint('GET orders/admin/all params: $params');

      final response = await _client.get(
        'orders/admin/all',
        queryParameters: params,
      );

      debugPrint("RESP status=${response.statusCode} data=${response.data}");

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final dataWrapper = raw['data'];
          if (dataWrapper is Map<String, dynamic>) {
            final paged = PagedResponse<PmOrderListItem>.fromJson(
              dataWrapper,
                  (m) => PmOrderListItem.fromJson(m),
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


  // for count of total orders in the dashboard

  Future<int> fetchOrdersCount() async {
    try {
      final response = await _client.get(
        'orders/all'
      );

      // expecting a response shape like:
      // { success: true, statusCode: 200, data: [ ... ], error: null }
      final raw = response.data;
      if (raw is Map && raw['data'] is List) {
        final list = raw['data'] as List;
        return list.length;
      }

      // Fallback: sometimes API returns paged wrapper with `data` -> { data: [], total: ... }
      if (raw is Map && raw['data'] is Map) {
        final inner = raw['data'] as Map;
        if (inner['data'] is List) {
          return (inner['data'] as List).length;
        }
        // if API returns total in the wrapper, prefer that
        if (inner['total'] is int) {
          return inner['total'] as int;
        }
      }

      // Unexpected format -> return 0 (or throw)
      return 0;
    } on DioException catch (e) {
      // handle network error - you might want to rethrow or return -1 to indicate error
      debugPrint('fetchOrdersCount network error: ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('fetchOrdersCount unexpected error: $e');
      return 0;
    }
  }

}

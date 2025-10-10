// services/orders_api.dart
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../models/orders/sales_order_stats.dart';

class SalesDashboardRepository {
  final ApiClient _client;

  SalesDashboardRepository([ApiClient? client])
    : _client = client ?? ApiClient();

  Future<ApiState<PagedResponse<OrderResponseModel>>> fetchOrders({
    int? userId,
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

      if (userId != -1) {
        params['userId'] = userId;
      }
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
        'orders/sales',
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


  // for sales user dashboard stats

  Future<ApiState<OrderStats>> fetchOrderStats({int? salesId}) async {
    try {
      final params = <String, dynamic>{};
      if (salesId != null) params['salesId'] = salesId;
      final response = await _client.get(
        'orders/dashboard/stats',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final data = raw['data'];
          if (data is Map<String, dynamic>) {
            final stats = OrderStats.fromJson(data);
            return ApiData(stats);
          }
          return const ApiError('Invalid data format');
        }
        return const ApiError('Unexpected response format');
      }
      return ApiError('Server error: ${response.statusCode}');
    } on DioException catch (e) {
      final msg =
          (e.response?.data is Map && e.response!.data['error'] != null)
              ? e.response!.data['error'].toString()
              : e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }
}

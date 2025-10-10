// lib/services/production_manager_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:microsensors/models/orders/production_manager_change_status_response.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/paged_response.dart';
import '../../../models/orders/production_manager_order_list.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/production_manager_stats.dart';

class ProductionManagerRepository {
  final ApiClient _client;

  ProductionManagerRepository([ApiClient? client])
      : _client = client ?? ApiClient();

  /// Fetch paged orders for Production Manager
  Future<ApiState<PagedResponse<PmOrderListItem>>> fetchOrders({
    required int pmId,
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
      debugPrint('GET orders/pm/$pmId params: $params');

      final response = await _client.get(
        'orders/pm/$pmId',
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


  Future<ApiState<PmOrderStats>> fetchStats({
    required int pmId,
  }) async {
    try {
      final response = await _client.get('orders/pm/$pmId/stats');

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final data = raw['data'];
          if (data is Map<String, dynamic>) {
            final stats = PmOrderStats.fromJson(data);
            return ApiData(stats);
          }
          return const ApiError('Invalid stats format');
        }
        return const ApiError('Unexpected response format');
      }
      return ApiError('Server error: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = (e.response?.data is Map &&
          e.response!.data['error'] != null)
          ? e.response!.data['error'].toString()
          : e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  /// Change order status API call
  Future<ApiState<ProductionManagerChangeStatusResponse>> changeOrderStatus({
    required int orderId,
    required String newStatus,
    required int changedBy,
  }) async {
    try {
      final body = {
        'newStatus': newStatus,
        'changedBy': changedBy,
      };

      // POST /api/orders/{orderId}/status
      final response = await _client.post('orders/$orderId/status', data: body);

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final data = raw['data'];
          if (data is Map<String, dynamic>) {
            final model = ProductionManagerChangeStatusResponse.fromJson(data);
            return ApiData(model);
          } else {
            return const ApiError('Invalid response format');
          }
        } else {
          return const ApiError('Unexpected response format from server');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && e.response!.data['error'] != null)
          ? e.response!.data['error'].toString()
          : e.message ?? 'Network error';
      return ApiError(msg, error: e);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

}

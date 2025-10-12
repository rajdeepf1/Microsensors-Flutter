// lib/services/production_manager_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:microsensors/models/orders/change_order_status_model.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/paged_response.dart';


class ProductionManagerRepository {
  final ApiClient _client;

  ProductionManagerRepository([ApiClient? client])
      : _client = client ?? ApiClient();

  /// Fetch paged orders for Production Manager
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
        'orders/pm',
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

  /// Change order status API call
  Future<ApiState<ChangeOrderStatusModel>> changeOrderStatus({
    required int orderId,
    required String newStatus,
    required int changedBy,
  }) async {
    try {
      final body = {
        'newStatus': newStatus,
        'changedBy': changedBy,
      };

      final response = await _client.post('orders/$orderId/status', data: body);

      if (response.statusCode == 200 || response.statusCode == 400) {
        // accept both 200 and 400 since backend may return handled error
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          final model = ChangeOrderStatusModel.fromJson(raw);

          if (model.isSuccess) {
            return ApiData(model);
          } else {
            return ApiError(model.error ?? 'Failed to change status');
          }
        } else {
          return const ApiError('Unexpected response format from server');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
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

}

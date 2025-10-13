// services/orders_api.dart
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_response_model.dart';
import '../../../models/orders/order_status_count_model.dart';
import '../../../models/orders/paged_response.dart';
import '../../../models/orders/sales_order_stats.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/user_model/user_model.dart';

class ProductPageResult {
  final List<ProductDataModel> items;
  final int? total;

  ProductPageResult({required this.items, this.total});
}

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

/*Add Orders*/

  Future<ApiState<List<UserDataModel>>> fetchUsersByRoleId(int roleId) async {
    try {
      final response = await _client.get('user/by-role-id/$roleId');

      // Response should be your ApiResponse wrapper:
      // { success: true, statusCode: 200, data: [ {..}, {...} ], error: null }
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = (response.data as Map).cast<
            String,
            dynamic>();
        final bool success = json['success'] as bool? ?? false;

        if (!success) {
          final errorMsg = json['error']?.toString() ?? 'Unknown API error';
          return ApiError(errorMsg);
        }

        final rawList = (json['data'] as List<dynamic>?) ?? [];
        final users = rawList.map((e) =>
            UserDataModel.fromJson((e as Map).cast<String, dynamic>())).toList();
        return ApiData(users);
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioException catch (dioErr, st) {
      // Detailed Dio error handling for better messages
      if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
        return ApiError('Connection timed out', error: dioErr, stackTrace: st);
      } else if (dioErr.response != null) {
        final status = dioErr.response?.statusCode;
        String msg = 'Request failed (${status ?? 'unknown'})';
        try {
          final body = dioErr.response?.data;
          if (body is Map && body['error'] != null) {
            msg = body['error'].toString();
          } else if (body is String) {
            msg = body;
          }
        } catch (_) {}
        return ApiError(msg, error: dioErr, stackTrace: st);
      } else {
        return ApiError(
            dioErr.message ?? 'Network error', error: dioErr, stackTrace: st);
      }
    } catch (e, st) {
      return ApiError(e.toString(), error: e, stackTrace: st);
    }
  }


  /* Add Orders: new method to call POST /api/orders/add-order */
  Future<ApiState<String>> addOrder({
    required int salesPersonId,
    required int productionManagerId,
    required String clientName,
    String? remarks,
    required List<Map<String, dynamic>> items, // [{productId, quantity}, ...]
  }) async {
    try {
      final body = <String, dynamic>{
        'salesPersonId': salesPersonId,
        'productionManagerId': productionManagerId,
        'clientName': clientName,
        'remarks': remarks ?? '',
        'items': items,
      };

      debugPrint('POST orders/add-order body: $body');

      final response = await _client.post('orders/add-order', data: body);

      debugPrint('ADD ORDER resp: status=${response.statusCode} data=${response.data}');

      // The API returns 201 for created in your example
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Normalize message from response.data
        if (response.data is Map<String, dynamic>) {
          final raw = response.data as Map<String, dynamic>;
          final msg = raw['data']?.toString() ?? 'Order created';
          return ApiData(msg);
        } else if (response.data is String) {
          return ApiData(response.data as String);
        } else {
          return const ApiData('Order created');
        }
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


  Future<ApiState<ProductPageResult>> fetchProductsPage({
    required int page,
    required int pageSize,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (search != null && search.isNotEmpty) params['q'] = search;
      if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) params['dateTo'] = dateTo;

      final response = await _client.get('products', queryParameters: params);

      if (response.statusCode != 200) {
        return ApiError('Server error: ${response.statusCode}');
      }

      final raw = response.data;
      if (raw is Map && raw['data'] is Map) {
        final payload = raw['data'] as Map;
        final listRaw = payload['data'];
        final total = payload['total'] is int ? payload['total'] as int : null;

        List<ProductDataModel> items = [];
        if (listRaw is List) {
          items = listRaw
              .map((e) => ProductDataModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        return ApiData(ProductPageResult(items: items, total: total));
      } else {
        return const ApiError('Unexpected paged response format');
      }
    } on DioException catch (dioErr, st) {
      final msg = dioErr.response?.data is Map && dioErr.response?.data['error'] != null
          ? dioErr.response?.data['error'].toString()
          : dioErr.message ?? 'Network error';
      return ApiError(msg!, error: dioErr, stackTrace: st);
    } catch (e, st) {
      return ApiError(e.toString(), error: e, stackTrace: st);
    }
  }

/*Add Orders*/


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


}

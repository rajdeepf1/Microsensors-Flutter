// lib/features/products/repository/product_list_repository.dart
import 'package:dio/dio.dart';
import 'package:microsensors/models/orders/orders_request.dart';
import 'package:microsensors/models/orders/orders_response.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/user_model/user_model.dart';

class ProductPageResult {
  final List<ProductDataModel> items;
  final int? total;

  ProductPageResult({required this.items, this.total});
}

class SalesProductListRepository {
  final ApiClient _client;
  SalesProductListRepository([ApiClient? client]) : _client = client ?? ApiClient();

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


  Future<ApiState<OrderResponse>> createOrder(OrderRequest req) async {
    try {
      final response = await _client.post(
        'orders/add-order',
        data: req.toJson(),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final raw = response.data;
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (raw is Map) {
          final body = Map<String, dynamic>.from(raw);
          final resp = OrderResponse.fromJson(body);
          if (resp.success) return ApiData(resp);
          return ApiError(resp.error ?? 'Order Create failed', error: resp);
        }
        return const ApiError('Unexpected response format');
      }

      // non-2xx
      if (raw is Map && raw['error'] != null) {
        return ApiError(raw['error'].toString());
      }

      return ApiError('Unexpected status: ${response.statusCode}');
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

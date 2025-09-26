// services/orders_api.dart
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/orders/order_models.dart';
import '../../../models/orders/sales_order_stats.dart';

class SalesDashboardRepository {
  final ApiClient _client;

  SalesDashboardRepository([ApiClient? client])
    : _client = client ?? ApiClient();

  // Future<ApiState<PagedResponse<OrderListItem>>> fetchOrders({
  //   required int salesId,
  //   int page = 0,
  //   int size = 10,
  //   String? q, // <-- optional search query
  //   String? sort, // optional if you want later
  // }) async {
  //   try {
  //     // build query params dynamically
  //     final Map<String, dynamic> params = {'page': page, 'size': size};
  //     if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
  //     if (sort != null && sort.isNotEmpty) params['sort'] = sort;
  //
  //     final response = await _client.get(
  //       'orders/get-orders/$salesId',
  //       queryParameters: params,
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final raw = response.data;
  //       if (raw is Map<String, dynamic>) {
  //         final dataWrapper = raw['data'];
  //         if (dataWrapper is Map<String, dynamic>) {
  //           final paged = PagedResponse<OrderListItem>.fromJson(
  //             dataWrapper,
  //             (m) => OrderListItem.fromJson(m),
  //           );
  //           return ApiData(paged);
  //         }
  //         return const ApiError('Invalid data format');
  //       } else if (raw is Map) {
  //         // sometimes Dio gives a LinkedHashMap that isn't typed exactly
  //         final map = Map<String, dynamic>.from(raw);
  //         final dataWrapper = map['data'];
  //         if (dataWrapper is Map) {
  //           final dataMap = Map<String, dynamic>.from(dataWrapper);
  //           final paged = PagedResponse<OrderListItem>.fromJson(
  //             dataMap,
  //             (m) => OrderListItem.fromJson(Map<String, dynamic>.from(m)),
  //           );
  //           return ApiData(paged);
  //         }
  //         return const ApiError('Invalid data format');
  //       }
  //       return const ApiError('Unexpected response format');
  //     }
  //
  //     return ApiError('Server error: ${response.statusCode}');
  //   } on DioException catch (e) {
  //     final msg =
  //         (e.response?.data is Map && e.response!.data['error'] != null)
  //             ? e.response!.data['error'].toString()
  //             : e.message ?? 'Network error';
  //     return ApiError(msg, error: e);
  //   } catch (e, st) {
  //     return ApiError('Unexpected error: $e', error: e, stackTrace: st);
  //   }
  // }


  Future<ApiState<PagedResponse<OrderListItem>>> fetchOrders({
    required int salesId,
    int page = 0,
    int size = 10,
    String? q, // optional search query
    String? sort, // optional sort
    String? dateFrom, // optional yyyy-MM-dd
    String? dateTo,   // optional yyyy-MM-dd
  }) async {
    try {
      // build query params dynamically
      final Map<String, dynamic> params = {
        'page': page,
        'size': size,
      };

      if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
      if (sort != null && sort.isNotEmpty) params['sort'] = sort;
      if (dateFrom != null && dateFrom.trim().isNotEmpty) params['dateFrom'] = dateFrom.trim();
      if (dateTo != null && dateTo.trim().isNotEmpty) params['dateTo'] = dateTo.trim();

      final response = await _client.get(
        'orders/get-orders/$salesId',
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        // Normalize response body to Map<String, dynamic>
        Map<String, dynamic>? mapBody;
        if (raw is Map<String, dynamic>) {
          mapBody = raw;
        } else if (raw is Map) {
          mapBody = Map<String, dynamic>.from(raw);
        }

        if (mapBody != null) {
          final dataWrapper = mapBody['data'];
          if (dataWrapper is Map<String, dynamic>) {
            final paged = PagedResponse<OrderListItem>.fromJson(
              dataWrapper,
                  (m) => OrderListItem.fromJson(m),
            );
            return ApiData(paged);
          } else if (dataWrapper is Map) {
            final dataMap = Map<String, dynamic>.from(dataWrapper);
            final paged = PagedResponse<OrderListItem>.fromJson(
              dataMap,
                  (m) => OrderListItem.fromJson(Map<String, dynamic>.from(m)),
            );
            return ApiData(paged);
          } else {
            return const ApiError('Invalid data format');
          }
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

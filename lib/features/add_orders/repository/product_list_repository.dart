// lib/features/products/repository/product_list_repository.dart
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';

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
    String? status,
    String? search
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };
      if (status != null) params['status'] = status;
      if (search != null && search.isNotEmpty) params['q'] = search;

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
}

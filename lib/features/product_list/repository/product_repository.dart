import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';

class ProductRepository {
  final ApiClient _client;
  ProductRepository([ApiClient? client]) : _client = client ?? ApiClient();

  Future<ApiState<List<ProductDataModel>>> fetchProducts() async {
    try {
      final response = await _client.get('products/all'); // adjust endpoint
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = (response.data as Map).cast<String, dynamic>();
        final productListResponse = ProductListResponse.fromJson(json);

        if (!productListResponse.success) {
          return ApiError(productListResponse.error ?? 'Unknown API error');
        }

        final products = productListResponse.toProductList();
        return ApiData(products);
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioError catch (dioErr, st) {
      // (same error handling pattern as your other repos)
      if (dioErr.type == DioErrorType.connectionTimeout ||
          dioErr.type == DioErrorType.receiveTimeout) {
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
}

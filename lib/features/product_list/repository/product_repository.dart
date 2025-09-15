import 'dart:io';

import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/product/ProductDeleteResponse.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/product/product_request.dart';
import '../../../models/product/product_response.dart';

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

  Future<ApiState<ProductResponse>> uploadProductImage(int productId, File file) async {
    try {
      final fileName = file.path.split('/').last;
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _client.post(
        'products/$productId/image',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );

      final raw = response.data;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (raw is Map) {
          final body = Map<String, dynamic>.from(raw);
          final resp = ProductResponse.fromJson(body);
          if (resp.success) return ApiData(resp);
          return ApiError(resp.error ?? 'Upload failed', error: resp);
        }
        return const ApiError('Unexpected response format');
      }

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

  Future<ApiState<ProductResponse>> updateProduct(ProductRequest req, int productId) async {
    try {
      final response = await _client.put(
        'products/${productId}',
        data: req.toJson(),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final raw = response.data;
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (raw is Map) {
          final body = Map<String, dynamic>.from(raw);
          final resp = ProductResponse.fromJson(body);
          if (resp.success) return ApiData(resp);
          return ApiError(resp.error ?? 'Create failed', error: resp);
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

  Future<ApiState<ProductDeleteResponse>> deleteProduct(int productId) async {
    try {
      final response = await _client.delete(
        'products/$productId',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final raw = response.data;

        if (raw is Map<String, dynamic>) {
          final resp = ProductDeleteResponse.fromJson(raw);
          if (resp.success) {
            return ApiData(resp);
          } else {
            return ApiError(resp.error ?? 'Delete failed', error: resp);
          }
        }

        // Fallback: if API just sends plain string "Product Deleted"
        if (raw is String) {
          return ApiData(ProductDeleteResponse(
            success: true,
            statusCode: response.statusCode ?? 200,
            data: raw,
            error: null,
          ));
        }

        // No body case (204 No Content)
        return ApiData(ProductDeleteResponse(
          success: true,
          statusCode: response.statusCode ?? 200,
          data: 'Product Deleted',
          error: null,
        ));
      }

      return ApiError('Unexpected status: ${response.statusCode}');
    } on DioException catch (e, st) {
      final body = e.response?.data;
      String msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : e.message ?? 'Network error';

      return ApiError(msg, error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


}

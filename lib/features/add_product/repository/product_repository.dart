import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_request.dart';
import '../../../models/product/product_response.dart';

class ProductRepository {
  final ApiClient _client;
  ProductRepository([ApiClient? client]) : _client = client ?? ApiClient();

  /// Create product -> POST /api/products/add-product
  Future<ApiState<ProductResponse>> createProduct(ProductRequest req) async {
    try {
      final response = await _client.post(
        'products/add-product',
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

  /// Upload product image -> POST /api/products/{id}/image (multipart/form-data)
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
}

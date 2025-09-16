// dashboard_repository.dart
import 'dart:io';

import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/product/product_list_response.dart' as prod_model; // if needed

class DashboardRepository {
  final ApiClient _client;
  DashboardRepository([ApiClient? client]) : _client = client ?? ApiClient();

  Future<ApiState<List<UserDataModel>>> fetchUsers() async {
    try {
      final response = await _client.get('user/all-active-non-active');
      if (response.statusCode == 200) {
        final raw = response.data;
        // expected shape: { success: true, statusCode: 200, data: [ ... ], error: null }
        if (raw is Map && raw['data'] is List) {
          final list = (raw['data'] as List)
              .map((e) => UserDataModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return ApiData<List<UserDataModel>>(list);
        } else if (raw is List) {
          final list = raw.map((e) => UserDataModel.fromJson(Map<String, dynamic>.from(e))).toList();
          return ApiData<List<UserDataModel>>(list);
        } else {
          return const ApiError('Unexpected users response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioError catch (dioErr, st) {
      if (dioErr.type == DioErrorType.connectionTimeout || dioErr.type == DioErrorType.receiveTimeout) {
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

  Future<ApiState<List<ProductDataModel>>> fetchProducts() async {
    try {
      final response = await _client.get('products/all');
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map && raw['data'] is List) {
          final list = (raw['data'] as List)
              .map((e) => ProductDataModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return ApiData<List<ProductDataModel>>(list);
        } else if (raw is List) {
          final list = raw.map((e) => ProductDataModel.fromJson(Map<String, dynamic>.from(e))).toList();
          return ApiData<List<ProductDataModel>>(list);
        } else {
          return const ApiError('Unexpected products response format');
        }
      } else {
        return ApiError('Server error: ${response.statusCode}');
      }
    } on DioError catch (dioErr, st) {
      if (dioErr.type == DioErrorType.connectionTimeout || dioErr.type == DioErrorType.receiveTimeout) {
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

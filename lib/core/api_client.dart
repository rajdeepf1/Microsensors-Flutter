// core/api_client.dart
import 'package:dio/dio.dart';
import '../utils/constants.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? Constants.apiBaseUrl, // fallback to Constants
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      await _dio.get(path, queryParameters: queryParameters, options: options);

  Future<Response> post(String path, {dynamic data, Options? options}) async =>
      await _dio.post(path, data: data, options: options);

  Future<Response> put(String path, {dynamic data, Options? options}) async =>
      await _dio.put(path, data: data, options: options);

  Future<Response> delete(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    return await _dio.delete(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

// core/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient()
      : _dio = Dio(
    BaseOptions(
      baseUrl: "https://jsonplaceholder.typicode.com",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<Response> get(String path) async => await _dio.get(path);
  Future<Response> post(String path, {dynamic data}) async =>
      await _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) async =>
      await _dio.put(path, data: data);
  Future<Response> delete(String path) async => await _dio.delete(path);
}

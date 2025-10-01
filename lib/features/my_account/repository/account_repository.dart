import 'package:dio/dio.dart';
import 'package:microsensors/core/api_state.dart';
import '../../../core/api_client.dart';

class AccountRepository {
  final ApiClient _client;
  AccountRepository([ApiClient? client]) : _client = client ?? ApiClient();

  Future<ApiState<String>> fetchUserCurrentPassword(int id) async {
    try {
      final Response<dynamic> response = await _client.post('user/$id/reveal-password');

      if (response.statusCode != 200) {
        return ApiError('Server error: ${response.statusCode}');
      }

      final body = response.data;
      if (body == null) return ApiError('Empty response');

      String? password;

      if (body is String) {
        password = body;
      } else if (body is Map) {
        // common shapes: { data: "..."} or { data: { password: "..." } } or { password: "..." }
        if (body['data'] is String) {
          password = body['data'] as String;
        } else if (body['data'] is Map && body['data']['password'] != null) {
          password = body['data']['password'].toString();
        } else if (body['password'] != null) {
          password = body['password'].toString();
        } else {
          password = body.toString();
        }
      } else {
        password = body.toString();
      }

      if (password != null && password.isNotEmpty) {
        return ApiData(password);
      } else {
        return ApiError('Password not present in response');
      }
    } on DioException catch (dioErr, st) {
      if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
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

import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/user_model/user_request_model.dart';


class SalesManagersUserRepository {
  final ApiClient _client;

  SalesManagersUserRepository([ApiClient? client]) : _client = client ?? ApiClient();

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
    } on DioError catch (dioErr, st) {
      // Detailed Dio error handling for better messages
      if (dioErr.type == DioErrorType.connectionTimeout ||
          dioErr.type == DioErrorType.receiveTimeout) {
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

}
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/user_model/user_request_model.dart';
import '../../../models/user_model/user_update_request.dart';


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


  Future<ApiState<UserResponseModel>> updateUser(UpdateUserForSalesAndManagerRequest req) async {
    try {
      // Use PUT or POST depending on your backend. Here I use PUT /user/{id}
      final response = await _client.put(
        'user/${req.userId}', // adapt to your API (or use 'user/update')
        data: req.toJson(),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          try {
            final userResp = UserResponseModel.fromJson(Map<String, dynamic>.from(raw));
            if (userResp.success) {
              return ApiData(userResp);
            } else {
              return ApiError(userResp.error?.toString() ?? 'Update failed');
            }
          } catch (e, st) {
            return ApiError('Failed to parse response: $e', error: e, stackTrace: st);
          }
        } else {
          return const ApiError('Unexpected response format');
        }
      }

      return ApiError('Unexpected status code: ${response.statusCode}');
    } on DioException catch (e, st) {
      final msg = (e.response?.data is Map && e.response!.data['message'] != null)
          ? e.response!.data['message'].toString()
          : e.message;
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


  Future<ApiState<UserResponseModel>> uploadProfileImage(int userId, File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;

      final formData = FormData.fromMap({
        // the controller expects the file in the part named "file"
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      // NOTE: endpoint path must match your controller mapping
      final response = await _client.post(
        'user/$userId/avatar',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          // do NOT set content-length manually
        ),
      );

      // Expecting your ApiResponse wrapper { success: bool, statusCode: int, data: {...}, error: ... }
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is Map<String, dynamic>) {
          try {
            final userResp = UserResponseModel.fromJson(Map<String, dynamic>.from(raw));
            if (userResp.success) {
              return ApiData(userResp);
            } else {
              return ApiError(userResp.error?.toString() ?? 'Upload failed');
            }
          } catch (e, st) {
            return ApiError('Failed to parse server response: $e', error: e, stackTrace: st);
          }
        } else {
          return const ApiError('Unexpected response format from server');
        }
      }

      return ApiError('Unexpected status code: ${response.statusCode}');
    } on DioException catch (e, st) {
      return ApiError('Network error: ${e.message}', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  Future<ApiState<String>> deleteUser(int userId, int deletedBy) async {
    try {
      final response = await _client.delete(
        'user/$userId',
        queryParameters: {'deletedBy': deletedBy},
      );

      final raw = response.data;
      if (response.statusCode == 200) {
        if (raw is Map<String, dynamic>) {
          final success = raw['success'] as bool? ?? false;
          if (success) {
            return ApiData(raw['data']?.toString() ?? 'User deleted');
          }
          return ApiError(raw['error']?.toString() ?? 'Delete failed');
        }
        return const ApiError('Unexpected response format');
      }

      return ApiError('Unexpected status: ${response.statusCode}');
    } on DioException catch (e, st) {
      final msg = (e.response?.data is Map && e.response!.data['error'] != null)
          ? e.response!.data['error'].toString()
          : e.message ?? 'Network error';
      return ApiError(msg, error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


}
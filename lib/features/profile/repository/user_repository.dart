import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/user_model/user_request_model.dart';

class UserRepository {
  final ApiClient _client;
  UserRepository([ApiClient? client]) : _client = client ?? ApiClient();

  /// Upload avatar to endpoint: POST /user/{id}/avatar (multipart/form-data)
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


  /// Update user profile (partial). Returns wrapped UserResponseModel on success.
  Future<ApiState<UserResponseModel>> updateUser(UpdateUserRequest req) async {
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



}

import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';

class AddUserRepository {
  final ApiClient _client;
  AddUserRepository([ApiClient? client]) : _client = client ?? ApiClient();


  Future<ApiState<UserResponseModel>> createUser({
    required String username,
    required String email,
    required String mobileNumber,
    required String password,
    required int roleId,
    required bool isActive,
  }) async {
    try {
      final response = await _client.post(
        'user/add-user',
        data: {
          "username": username,
          "email": email,
          "mobileNumber": mobileNumber,
          "password": password,
          "roleId": roleId,
          "isActive": isActive,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          final success = body['success'] == true;
          if (success) {
            return ApiData(UserResponseModel.fromJson(body));
          } else {
            // backend returned error message
            return ApiError(body['error']?.toString() ?? 'Failed to create user');
          }
        }
        return const ApiError('Unexpected response format');
      }

      return ApiError('Unexpected status: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && e.response!.data['error'] != null)
          ? e.response!.data['error'].toString()
          : e.message ?? 'Unknown network error';
      return ApiError('Network error: $msg', error: e);
    }
  }

  Future<ApiState<UserResponseModel>> uploadProfileImage(int userId, File file) async {
    try {
      final fileName = file.path.split('/').last;

      final formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      final response = await _client.post(
        "user/$userId/avatar",
        data: formData,
        options: Options(contentType: "multipart/form-data"),
      );

      if (response.statusCode == 200) {
        return ApiData(UserResponseModel.fromJson(response.data));
      }
      return ApiError('Unexpected status: ${response.statusCode}');
    } on DioException catch (e, st) {
      return ApiError('Network error: ${e.message}', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

}

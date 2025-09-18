// lib/services/fcm_service.dart  (or wherever you keep it)
import 'package:dio/dio.dart';
import 'package:microsensors/core/api_client.dart';
import 'package:microsensors/core/api_state.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/utils/constants.dart';

class FcmService {
  final ApiClient apiClient;

  FcmService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient(baseUrl: Constants.apiBaseUrl);

  /// Registers a token for a user.
  /// Returns ApiData(UserDataModel) on success or ApiError(...) on failure.
  Future<ApiState<UserDataModel>> registerToken({
    required int userId,
    required String token,
  }) async {
    final encodedToken = Uri.encodeComponent(token);
    // match your Spring controller path (adjust if your baseUrl already contains /api)
    final path = 'user/token?userId=$userId&token=$encodedToken';

    try {
      final resp = await apiClient.post(path);
      final status = resp.statusCode ?? 0;

      if (status >= 200 && status < 300) {
        final body = resp.data;
        if (body is Map<String, dynamic>) {
          final success = body['success'] == true;
          final data = body['data'];

          if (success && data != null && data is Map<String, dynamic>) {
            try {
              final user = UserDataModel.fromJson(Map<String, dynamic>.from(data));
              return ApiData<UserDataModel>(user);
            } catch (e) {
              return ApiError<UserDataModel>('Failed to parse user data: $e');
            }
          } else {
            final errMsg = body['error']?.toString() ?? 'Server returned success=false or no data';
            return ApiError<UserDataModel>(errMsg);
          }
        } else {
          return ApiError<UserDataModel>('Unexpected response format from server');
        }
      } else {
        // non-2xx
        if (status >= 400 && status < 500) {
          return ApiError<UserDataModel>('Client error: ${resp.statusCode}');
        } else {
          return ApiError<UserDataModel>('Server error: ${resp.statusCode}');
        }
      }
    } on DioException catch (e) {
      // Dio 5 uses DioException
      final respStatus = e.response?.statusCode;
      final respData = e.response?.data;
      if (respStatus != null && respStatus >= 400 && respStatus < 500) {
        final message = (respData is Map && respData['error'] != null)
            ? respData['error'].toString()
            : 'Client error: $respStatus';
        return ApiError<UserDataModel>(message);
      }
      return ApiError<UserDataModel>('Network error: ${e.message}');
    } catch (e) {
      return ApiError<UserDataModel>('Unexpected error: $e');
    }
  }
}

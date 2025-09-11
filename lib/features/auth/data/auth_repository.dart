// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository([ApiClient? client]) : _client = client ?? ApiClient();

  /// Calls GET user/getUserByNumber, parses ApiResponse, then sends OTP.
  /// Returns ApiState<ApiResponse> on success (ApiResponse.data contains UserModel).
  Future<ApiState<ApiResponse>> fetchEmailByPhone(String phone) async {
    try {
      final response = await _client.get(
        'user/getUserByNumber',
        queryParameters: {'number': phone},
      );

      if (response.statusCode != 200) {
        return ApiError('Unexpected response: ${response.statusCode}');
      }

      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        return const ApiError('Unexpected response format');
      }

      // Parse into ApiResponse safely
      ApiResponse apiResp;
      try {
        apiResp = ApiResponse.fromJson(Map<String, dynamic>.from(raw));
      } catch (e, st) {
        return ApiError('Failed to parse API response: $e', error: e, stackTrace: st);
      }

      if (!apiResp.success || apiResp.data == null) {
        return ApiError('API returned error: ${apiResp.error ?? 'no data'}');
      }

      final user = apiResp.data!;

      // Send OTP and ensure we handle all outcomes
      final otpResult = await sendOtp(user);
      if (otpResult is ApiData<bool>) {
        if (otpResult.data == true) {
          // OTP sent: return the ApiResponse (contains user)
          return ApiData(apiResp);
        } else {
          return const ApiError('Failed to send OTP (unknown)');
        }
      } else if (otpResult is ApiError<bool>) {
        return ApiError('Failed to send OTP: ${otpResult.message}', error: otpResult.error, stackTrace: otpResult.stackTrace);
      } else {
        return const ApiError('Unexpected OTP result');
      }
    } on DioException catch (e, st) {
      final msg = _extractErrorMessage(e);
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      // VERY IMPORTANT: do not rethrow — return ApiError instead
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  /// Sends OTP. Returns ApiData(true) on HTTP 201; ApiError otherwise.
  Future<ApiState<bool>> sendOtp(UserModel user) async {
    try {
      final response = await _client.post(
        'otp/reques',
        data: {
          'userId': user.userId,
          'email': user.email,
          'username': user.username,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 201) {
        return const ApiData(true);
      } else {
        return ApiError('Failed to send OTP (status ${response.statusCode})');
      }
    } on DioException catch (e, st) {
      final msg = _extractErrorMessage(e);
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  /// Verifies OTP (otp/verify endpoint). Returns ApiData<UserModel> on success.
  Future<ApiState<UserModel>> verifyOtp(UserModel user, String otp) async {
    try {
      final response = await _client.post(
        'otp/verify',
        data: {'userId': user.userId, 'code': otp},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode != 200) {
        return ApiError('Verification failed: ${response.statusCode}');
      }

      final body = response.data;
      if (body is Map<String, dynamic>) {
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          try {
            final returnedUser = UserModel.fromJson(Map<String, dynamic>.from(data));
            return ApiData(returnedUser);
          } catch (_) {
            // If server returned data that can't be parsed, fall back to original user
            return ApiData(user);
          }
        } else {
          // success but no data — return original user
          return ApiData(user);
        }
      } else {
        return const ApiError('Unexpected verify response format');
      }
    } on DioException catch (e, st) {
      final msg = _extractErrorMessage(e);
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }

  String _extractErrorMessage(DioException e) {
    try {
      if (e.response?.data is Map<String, dynamic>) {
        final map = Map<String, dynamic>.from(e.response!.data as Map);
        return map['message']?.toString() ?? e.message ?? 'Unknown error';
      }
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }
}

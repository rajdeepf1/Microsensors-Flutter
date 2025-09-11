// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/otp/OTPResponse.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository([ApiClient? client]) : _client = client ?? ApiClient();

  // auth_repository.dart (relevant method)
  Future<ApiState<UserResponseModel>> fetchEmailByPhone(String phone) async {
    try {
      final response = await _client.get(
        'user/getUserByNumber',
        queryParameters: {'number': phone},
      );

      if (response.statusCode != 200) {
        return ApiError('Unexpected response: ${response.statusCode}');
      }

      final raw = response.data;
      if (raw == null || raw is! Map) {
        return const ApiError('Unexpected response format');
      }

      final Map<String, dynamic> body = Map<String, dynamic>.from(raw as Map);

      // Parse wrapper
      late UserResponseModel userResp;
      try {
        userResp = UserResponseModel.fromJson(body);
      } catch (e, st) {
        return ApiError('Failed to parse response: $e', error: e, stackTrace: st);
      }

      // If backend indicates failure in wrapper
      if (!userResp.success) {
        return ApiError(userResp.error?.toString() ?? 'Server returned failure');
      }

      // If you want to chain sendOtp: convert wrapper.data -> UserModel (if needed)
      final userData = userResp.data;
      if (userData == null) {
        return ApiError('No user data in response');
      }

      // If sendOtp expects UserModel, convert. Assume UserModel.fromJson exists:
      UserDataModel userModel;
      try {
        userModel = UserDataModel.fromJson(Map<String, dynamic>.from(userData.toJson()));
      } catch (_) {
        // If conversion fails, still continue (or fail based on your app needs)
        return const ApiError('Failed to convert user data');
      }

      final otpResult = await sendOtp(userModel);
      if (otpResult is ApiData<bool> && otpResult.data == true) {
        // RETURN the wrapper to the UI (success)
        return ApiData(userResp);
      } else if (otpResult is ApiError<bool>) {
        return ApiError('Failed to send OTP: ${otpResult.message ?? otpResult.error}');
      } else {
        return const ApiError('Failed to send OTP (unknown)');
      }
    } on DioException catch (e, st) {
      final msg = _extractErrorMessage(e);
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }




  /// Sends OTP. Returns ApiData(true) on success; ApiError otherwise.
  Future<ApiState<bool>> sendOtp(UserDataModel user) async {
    try {
      final response = await _client.post(
        'otp/request',
        data: {
          'userId': user.userId,
          'email': user.email,
          'username': user.username,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // Accept 201 or a 200 body with success:true
      if (response.statusCode == 201) {
        return const ApiData(true);
      }

      final raw = response.data;
      if (raw is Map) {
        final Map<String, dynamic> body = Map<String, dynamic>.from(raw as Map);
        if (body['success'] == true || body['statusCode'] == 201 || body['statusCode'] == 200) {
          return const ApiData(true);
        } else {
          final msg = (body['error'] ?? body['message'] ?? 'Failed to send OTP').toString();
          return ApiError(msg);
        }
      }

      // If server returned a simple string
      if (raw is String && raw.toLowerCase().contains('success')) {
        return const ApiData(true);
      }

      return ApiError('Failed to send OTP (status ${response.statusCode})');
    } on DioException catch (e, st) {
      final msg = _extractErrorMessage(e);
      return ApiError('Network error: $msg', error: e, stackTrace: st);
    } catch (e, st) {
      return ApiError('Unexpected error: $e', error: e, stackTrace: st);
    }
  }


  /// Verifies OTP (otp/verify endpoint). Returns ApiData<OtpResponse> on success.
  Future<ApiState<OtpResponse>> verifyOtp(UserDataModel user, String otp) async {
    try {
      final response = await _client.post(
        'otp/verify',
        data: {'userId': user.userId, 'code': otp},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // If HTTP not 200, try to extract server message and return ApiError
      if (response.statusCode != 200) {
        final raw = response.data;
        if (raw is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
          final msg = (map['error'] ?? map['message'] ?? 'Verification failed').toString();
          return ApiError(msg);
        }
        return ApiError('Verification failed: HTTP ${response.statusCode}');
      }

      final raw = response.data;
      // Response should be a Map like: { success: true, statusCode: 200, data: "...", error: null }
      if (raw is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
        // parse into your OtpResponse model (handles types safely)
        try {
          final otpResp = OtpResponse.fromJson(map);
          if (otpResp.success && (otpResp.statusCode == 200 || otpResp.statusCode == 201)) {
            return ApiData(otpResp);
          } else {
            final msg = otpResp.error ?? otpResp.data ?? 'OTP verification failed';
            return ApiError(msg);
          }
        } catch (e, st) {
          return ApiError('Failed to parse verify response: $e', error: e, stackTrace: st);
        }
      }

      // Some servers return plain string "OTP verified successfully." — treat as success
      if (raw is String && raw.toLowerCase().contains('success')) {
        return ApiData(OtpResponse(success: true, statusCode: 200, data: raw, error: null));
      }

      return const ApiError('Unexpected verify response format');
    } on DioException catch (e, st) {
      // If server returned a body with explanation for 4xx, extract it
      final resp = e.response;
      if (resp != null) {
        try {
          final raw = resp.data;
          if (raw is Map) {
            final msg = (raw['message'] ?? raw['error'] ?? raw['detail'])?.toString() ?? 'Verification failed';
            return ApiError(msg, error: e, stackTrace: st);
          }
          return ApiError('Verification failed: ${resp.statusCode} - ${raw ?? resp.statusMessage}', error: e, stackTrace: st);
        } catch (_) {
          return ApiError('Verification failed: ${resp.statusCode}', error: e, stackTrace: st);
        }
      }
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

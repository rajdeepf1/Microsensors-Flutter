// // lib/features/auth/providers/auth_providers.dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:microsensors/models/user_model/user_model.dart';
// import '../../../core/api_state.dart';
// import '../../../core/local_storage_service.dart';
// import '../data/auth_repository.dart';
// import 'auth_repository_provider.dart';
//
// class AuthNotifier extends Notifier<ApiState<UserModel>> {
//   late final AuthRepository _repo;
//   final _storage = LocalStorageService();
//
//   UserModel? _pendingUser;
//
//   @override
//   ApiState<UserModel> build() {
//     _repo = ref.read(authRepositoryProvider);
//     return const ApiInitial();
//   }
//
//   Future<ApiState<UserModel>> fetchEmail(String phone) async {
//     state = const ApiLoading();
//     final res = await _repo.fetchEmailByPhone(phone); // ApiState<ApiResponse>
//
//     if (res is ApiData<ApiResponse>) {
//       final apiResp = res.data!;
//       final user = apiResp.data;
//       if (user == null) {
//         final err = const ApiError<UserModel>('No user data found in API response');
//         state = err;
//         return err;
//       }
//       _pendingUser = user;
//       final success = ApiData<UserModel>(user);
//       state = success; // OTP sent -> show OTP fields
//       return success;
//     } else if (res is ApiError<ApiResponse>) {
//       final err = ApiError<UserModel>(res.message ?? 'Error', error: res.error, stackTrace: res.stackTrace);
//       state = err;
//       return err;
//     } else {
//       const fallback = ApiError<UserModel>('Unexpected result from fetchEmail');
//       state = fallback;
//       return fallback;
//     }
//   }
//
//   Future<ApiState<UserModel>> verifyOtp(String otp) async {
//     if (_pendingUser == null) {
//       final err = const ApiError<UserModel>('No user pending verification. Start login again.');
//       state = err;
//       return err;
//     }
//
//     state = const ApiLoading();
//     final res = await _repo.verifyOtp(_pendingUser!, otp); // ApiState<UserModel>
//
//     if (res is ApiData<UserModel>) {
//       final user = res.data;
//       await _storage.saveUser(user); // persist
//       _pendingUser = null;
//       final success = ApiData<UserModel>(user);
//       state = success;
//       return success;
//     } else if (res is ApiError<UserModel>) {
//       final err = ApiError<UserModel>(res.message ?? 'Verification error', error: res.error, stackTrace: res.stackTrace);
//       state = err;
//       return err;
//     } else {
//       const fallback = ApiError<UserModel>('Unexpected result from verifyOtp');
//       state = fallback;
//       return fallback;
//     }
//   }
//
//   Future<void> logout() async {
//     await _storage.removeUser();
//     _pendingUser = null;
//     state = const ApiInitial();
//   }
// }
//
// final authProvider = NotifierProvider<AuthNotifier, ApiState<UserModel>>(AuthNotifier.new);

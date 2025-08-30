// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../core/api_client.dart';
// import '../../core/api_state.dart';
// import '../data/auth_repository.dart';
// import '../models/user_model.dart';
//
// // Provide ApiClient globally
// final apiClientProvider = Provider<ApiClient>((ref) {
//   return ApiClient(baseUrl: "https://api.example.com");
// });
//
// // Provide AuthRepository
// final authRepositoryProvider = Provider<AuthRepository>((ref) {
//   return AuthRepository(ref.read(apiClientProvider));
// });
//
// // Login State Provider
// final loginProvider =
// StateNotifierProvider<LoginNotifier, ApiState<UserModel>>((ref) {
//   return LoginNotifier(ref.read(authRepositoryProvider));
// });
//
// // Login Notifier
// class LoginNotifier extends StateNotifier<ApiState<UserModel>> {
//   final AuthRepository repo;
//
//   LoginNotifier(this.repo) : super(const ApiState.idle());
//
//   Future<void> login(String email, String password) async {
//     state = const ApiState.loading();
//     try {
//       final user = await repo.login(email, password);
//       state = ApiState.success(user);
//     } catch (e) {
//       state = ApiState.error(e.toString());
//     }
//   }
// }

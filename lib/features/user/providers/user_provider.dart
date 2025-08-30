// features/users/state/user_notifier.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../data/user_repository.dart';

// Repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ApiClient());
});

// Users State Provider
final usersProvider =
StateNotifierProvider<UserNotifier, ApiState<List<UserModel>>>((ref) {
  return UserNotifier(ref.read(userRepositoryProvider));
});

class UserNotifier extends StateNotifier<ApiState<List<UserModel>>> {
  final UserRepository repository;

  UserNotifier(this.repository) : super(const ApiLoading());

  Future<void> fetchUsers() async {
    try {
      state = const ApiLoading();
      final users = await repository.fetchUsers();
      state = ApiData(users);
    } catch (e, st) {
      state = ApiError("Failed to fetch users", error: e, stackTrace: st);
    }
  }
}

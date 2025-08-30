// features/users/data/user_repository.dart
import '../../../core/api_client.dart';
import '../../../models/user_model/user_model.dart';

class UserRepository {
  final ApiClient apiClient;

  UserRepository(this.apiClient);

  Future<List<UserModel>> fetchUsers() async {
    final response = await apiClient.get("/users");
    final data = (response.data as List)
        .map((json) => UserModel.fromJson(json))
        .toList();
    return data;
  }
}

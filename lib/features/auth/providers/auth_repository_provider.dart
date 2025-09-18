// providers/auth_repository_provider.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/auth_repository.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient());
});

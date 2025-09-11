// providers/auth_repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../data/auth_repository.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient());
});

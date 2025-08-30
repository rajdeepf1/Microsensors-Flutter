// features/users/ui/users_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../providers/user_provider.dart';

class UsersScreen extends HookConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersProvider);

    // fetch when widget is mounted
    useEffect(() {
      Future.microtask(() =>
          ref.read(usersProvider.notifier).fetchUsers());
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(title: const Text("Users")),
      body: switch (state) {
        ApiLoading() => const Center(child: CircularProgressIndicator()),
        ApiData<List<UserModel>>(data: final users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              title: Text(user.name ?? ""),
              subtitle: Text(user.email ?? ""),
            );
          },
        ),
        ApiError(message: final msg) => Center(
          child: Text(
            msg,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        _ => const SizedBox(),
      },
    );
  }
}

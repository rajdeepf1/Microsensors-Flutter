import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/user_list/repository/sales_managers_user_repository.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';

import '../../../core/api_state.dart';
import '../../components/status_pill/status_pill.dart';

class SalesUserListScreen extends HookWidget {
  const SalesUserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apiState = useState<ApiState<List<UserDataModel>>>(const ApiInitial());
    final userApi = useMemoized(() => SalesManagersUserRepository());

    Future<void> loadUsers() async {
      apiState.value = const ApiLoading();
      final result = await userApi.fetchUsersByRoleId(2);
      apiState.value = result;
    }

    useEffect(() {
      loadUsers();
      return null;
    }, const []);

    Widget body;

    if (apiState.value is ApiInitial || apiState.value is ApiLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (apiState.value is ApiError<List<UserDataModel>>) {
      final err = apiState.value as ApiError<List<UserDataModel>>;
      body = _RetryView(
        message: err.message,
        onRetry: loadUsers,
      );
    } else if (apiState.value is ApiData<List<UserDataModel>>) {
      final data = (apiState.value as ApiData<List<UserDataModel>>).data;
      if (data.isEmpty) {
        body = _RetryView(
          message: 'No users found',
          onRetry: loadUsers,
        );
      } else {
        body = ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = data[index];
            final avatarUrl = user.userImage;
            return UserCardListWidget(
              name: user.username,
              email: user.email,
              mobileNumber: user.mobileNumber,
              roleName: user.roleName,
              avatarUrl: avatarUrl,
              isActive: user.isActive,
            );
          },
        );
      }
    } else {
      body = const Center(child: Text('Unknown state'));
    }

    return Scaffold(
      body: SafeArea(child: body),
    );
  }

}

/// Retry widget
class _RetryView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class UserCardListWidget extends StatelessWidget {
  final String name;
  final String email;
  final String mobileNumber;
  final String roleName;
  final String avatarUrl;
  final bool isActive;

  const UserCardListWidget({
    super.key,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.roleName,
    required this.avatarUrl,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: AppColors.card_color,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartImage(
              imageUrl: avatarUrl,
              baseUrl: Constants.apiBaseUrl,
              shape: ImageShape.circle,
              width: 70,
            ),
            const SizedBox(width: 16),
            // main info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name + status pill on one row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(active: isActive, height: 24),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Email
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          email,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mobile
                  Row(
                    children: [
                      const Icon(Icons.phone_android,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          mobileNumber,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Role
                  Row(
                    children: [
                      const Icon(Icons.card_membership_outlined,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        roleName,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

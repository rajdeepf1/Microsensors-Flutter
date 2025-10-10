// lib/features/products/presentation/add_orders.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/sales_user_dashboard/presentation/product_picker_sheet.dart';
import 'package:microsensors/features/sales_user_dashboard/repository/sales_dashboard_repository.dart';

import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/colors.dart';
import '../../add_orders/presentation/product_details.dart';
import '../../components/search_user_dropdown/search_user_dropdown.dart';

class AddOrders extends HookWidget {
  const AddOrders({super.key});

  @override
  Widget build(BuildContext context) {

    final repo = useMemoized(() => SalesDashboardRepository());

    // local editing flag derived from enableSaveNotifier (controls form editability)

    final selectedManager = useState<UserDataModel?>(null);
    final apiState = useState<ApiState<List<UserDataModel>>>(
      const ApiInitial(),
    );

    Future<void> loadUsers() async {
      apiState.value = const ApiLoading();
      final result = await repo.fetchUsersByRoleId(3);
      apiState.value = result;
    }

    useEffect(() {
      loadUsers();
      return null;
    }, const []);

    final allUsers =
        (apiState.value is ApiData<List<UserDataModel>>)
            ? (apiState.value as ApiData<List<UserDataModel>>).data
            : <UserDataModel>[];
    final isUsersLoading = apiState.value is ApiLoading;
    final usersLoadError =
        apiState.value is ApiError
            ? (apiState.value as ApiError).message
            : null;

    // search function (can be replaced with API call)
    Future<List<UserDataModel>> searchUsers(String q) async {
      final lower = q.toLowerCase();
      if (q.isEmpty) return allUsers;
      return allUsers
          .where(
            (u) =>
                u.username.toLowerCase().contains(lower) ||
                u.email.toLowerCase().contains(lower),
          )
          .toList();
    }

    return MainLayout(
      title: "Add Orders",

      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Production Managers"),
                  SizedBox(height: 10),
                  if (isUsersLoading)
                    const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (usersLoadError != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Failed to load users: $usersLoadError',
                        style: TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SearchUserDropdown(
                          hintText: 'Search users...',
                          searchFn: searchUsers,
                          onUserSelected: (u) => selectedManager.value = u,
                          maxOverlayHeight: 300,
                          showAllOnFocus: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            ProductEditField(
              text: "Client Name",
              child: TextFormField(
                controller: null,
                style: TextStyle(color: AppColors.subHeadingTextColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0 * 1.5,
                    vertical: 16.0,
                  ),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                ),
              ),
            ),

            ProductEditField(
              text: "Remarks",
              child: TextFormField(
                //initialValue: description,
                style: TextStyle(color: AppColors.subHeadingTextColor),
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              tooltip: 'Add products',
              onPressed: () async {
                final List<ProductDataModel>? picked = await showModalBottomSheet<List<ProductDataModel>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => const ProductPickerSheet(),
                );

                if (picked != null && picked.isNotEmpty) {
                  debugPrint('Picked product ids: ${picked.map((p) => p.productId).toList()}');
                  // Use picked (List<ProductDataModel>) — e.g. call API to add them to an order,
                  // or update your UI using picked.
                } else {
                  debugPrint('No products selected or picker cancelled.');
                }
              },
            ),



          ],
        ),
      ),
    );
  }
}

// edit_product.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/core/local_storage_service.dart';
import 'package:microsensors/features/components/quantity_edit_text/QuantityField.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/components/status_pill/status_pill.dart';
import 'package:microsensors/models/orders/orders_request.dart';
import 'package:microsensors/models/orders/orders_response.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import '../../../core/api_state.dart';
import '../../components/search_user_dropdown/search_user_dropdown.dart';
import '../repository/product_list_repository.dart';

class SalesProductDetails extends HookWidget {
  final int productId;
  final String name;
  final String description;
  final String sku;
  final String status;
  final String createdBy;
  final String createdAt;
  final String avatarUrl;
  final FocusNode? productNameFocusNode;
  final ValueNotifier<bool>? enableSaveNotifier;

  const SalesProductDetails({
    super.key,
    required this.productId,
    required this.name,
    required this.description,
    required this.sku,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.avatarUrl,
    this.productNameFocusNode,
    this.enableSaveNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final loading = useState<bool>(false);
    final repo = useMemoized(() => SalesProductListRepository());

    // local editing flag derived from enableSaveNotifier (controls form editability)
    final isEditing = useState<bool>(false);
    final quantity = useState<int>(0);

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

    Future<void> createAnOrder() async {
      if (quantity.value == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select the quantity, it can't be zero!"),
          ),
        );
        return;
      }

      final productionManagerId = selectedManager.value;
      final salesUserId = await LocalStorageService().getUser();

      if (productionManagerId == null ||
          productionManagerId.toString().isEmpty ||
          productionManagerId.userId.isNaN ||
          productionManagerId.userId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please select a user from the production manager's list!",
            ),
          ),
        );
        return;
      }

      loading.value = true;
      try {
        final req = OrderRequest(
          productId: productId,
          productionManagerId: productionManagerId.userId,
          quantity: quantity.value,
          salesPersonId: salesUserId!.userId,
          status: "Created",
        );

        // 1) Create product
        final createRes = await repo.createOrder(req);

        if (createRes is ApiData<OrderResponse>) {
          //final orderData = createRes.data.data;

          if (createRes.data.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order has been created successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Create order has been failed!')),
            );
          }
        } else if (createRes is ApiError<OrderResponse>) {
          // backend error message (e.g. SKU exists)
          final msg = createRes.message;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        context.pop();
      } finally {
        loading.value = false;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          SmartImage(
            imageUrl: avatarUrl,
            baseUrl: Constants.apiBaseUrl,
            username: name,
            height: 200,
            width: double.infinity,
          ),

          const SizedBox(height: 20),
          const Divider(),
          Form(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0 * 1.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    spacing: 20,
                    children: [Text("Status"), StatusPill(status: status)],
                  ),
                ),

                SizedBox(height: 20),

                ProductEditField(
                  text: "Product Name",
                  child: TextFormField(
                    initialValue: name,
                    focusNode: productNameFocusNode,
                    enabled: isEditing.value,
                    // editable only when editing
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
                  text: "Product Description",
                  child: TextFormField(
                    initialValue: description,
                    enabled: isEditing.value,
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
                ProductEditField(
                  text: "SKU",
                  child: TextFormField(
                    initialValue: sku,
                    enabled: false, // SKU remains read-only
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

                QuantityField(
                  label: "Quantity",
                  initialValue: 0,
                  onChanged: (value) => quantity.value = value,
                ),

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
              ],
            ),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: (loading.value) ? null : createAnOrder,
              child:
                  loading.value
                      ? const CircularProgressIndicator()
                      : const Text("Create an Order"),
            ),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }
}

class ProductEditField extends StatelessWidget {
  const ProductEditField({super.key, required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

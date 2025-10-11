// lib/features/products/presentation/add_orders.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/sales_user_dashboard/presentation/product_picker_sheet.dart';
import 'package:microsensors/features/sales_user_dashboard/repository/sales_dashboard_repository.dart';

import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/product/selected_products.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/colors.dart';
import '../../components/product_edit_field/product_edit_field.dart';
import '../../components/search_user_dropdown/search_user_dropdown.dart';

class AddOrders extends HookWidget {
  const AddOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => SalesDashboardRepository());

    final selectedManager = useState<UserDataModel?>(null);
    final apiState = useState<ApiState<List<UserDataModel>>>(const ApiInitial());
    final selectedProducts = useState<List<SelectedProducts>>(<SelectedProducts>[]);

    // controllers for client name and remarks (IMPORTANT: wired into the fields below)
    final clientNameCtrl = useTextEditingController();
    final remarksCtrl = useTextEditingController();

    // in-flight flag for submit button
    final submitting = useState<bool>(false);

    Future<void> loadUsers() async {
      apiState.value = const ApiLoading();
      final result = await repo.fetchUsersByRoleId(3);
      apiState.value = result;
    }

    useEffect(() {
      loadUsers();
      return null;
    }, const []);

    final allUsers = (apiState.value is ApiData<List<UserDataModel>>)
        ? (apiState.value as ApiData<List<UserDataModel>>).data
        : <UserDataModel>[];

    final isUsersLoading = apiState.value is ApiLoading;
    final usersLoadError =
    apiState.value is ApiError ? (apiState.value as ApiError).message : null;

    Future<List<UserDataModel>> searchUsers(String q) async {
      final lower = q.toLowerCase();
      if (q.isEmpty) return allUsers;
      return allUsers
          .where((u) =>
      u.username.toLowerCase().contains(lower) ||
          u.email.toLowerCase().contains(lower))
          .toList();
    }

    void _removeSelected(int productId) {
      selectedProducts.value = List<SelectedProducts>.from(selectedProducts.value)
        ..removeWhere((s) => s.product.productId == productId);
    }

    void _updateQuantity(int productId, int newQty) {
      final list = selectedProducts.value.map((s) {
        if (s.product.productId == productId) {
          // ensure at least 1
          final qty = newQty.clamp(1, 999999);
          return SelectedProducts(product: s.product, quantity: qty);
        }
        return s;
      }).toList(growable: false);
      selectedProducts.value = list;
    }

    Future<void> submitOrder() async {
      // simple validations
      if (selectedProducts.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one product.')),
        );
        return;
      }

      if (selectedManager.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a production manager.')),
        );
        return;
      }

      final clientName = clientNameCtrl.text.trim();
      if (clientName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter client name.')),
        );
        return;
      }

      // get stored user as salesPersonId (use LocalStorageService)
      final stored = await LocalStorageService().getUser();
      if (stored == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No stored user found (cannot determine sales person).')),
        );
        return;
      }

      final salesPersonId = stored.userId;
      final productionManagerId = selectedManager.value!.userId;
      final remarks = remarksCtrl.text.trim();

      // ensure quantities are valid (>=1) and build items payload: {productId, quantity}
      final items = selectedProducts.value
          .map((s) => <String, dynamic>{
        'productId': s.product.productId,
        'quantity': (s.quantity <= 0) ? 1 : s.quantity,
      })
          .toList();

      try {
        submitting.value = true;
        final res = await repo.addOrder(
          salesPersonId: salesPersonId,
          productionManagerId: productionManagerId,
          clientName: clientName,
          remarks: remarks,
          items: items,
        );

        if (res is ApiData<String>) {
          final message = res.data;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          // clear the form (optional)
          selectedProducts.value = [];
          clientNameCtrl.clear();
          remarksCtrl.clear();
          selectedManager.value = null;
          context.pop(true);
        } else if (res is ApiError<String>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add order: ${res.message}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected response from server')),
          );
        }
      } finally {
        submitting.value = false;
      }
    }

    return MainLayout(
      title: "Add Orders",
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Production Managers"),
                    const SizedBox(height: 10),
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
                          style: const TextStyle(color: Colors.red),
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

              // IMPORTANT: wire controllers into the fields
              ProductEditField(
                text: "Client Name",
                child: TextFormField(
                  controller: clientNameCtrl,
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
                  controller: remarksCtrl,
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

              // Add products button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_outlined, size: 38),
                    tooltip: 'Add products',
                    onPressed: () async {
                      final List<SelectedProducts>? picked =
                      await showModalBottomSheet<List<SelectedProducts>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => const ProductPickerSheet(),
                      );

                      if (picked != null && picked.isNotEmpty) {
                        // Ensure quantities are >= 1
                        final normalized = picked.map((s) {
                          final qty = (s.quantity <= 0) ? 1 : s.quantity;
                          return SelectedProducts(product: s.product, quantity: qty);
                        }).toList(growable: false);
                        selectedProducts.value = normalized;
                      }
                    },
                  ),
                  if (selectedProducts.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '${selectedProducts.value.length} product(s) selected',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Horizontal product list
              if (selectedProducts.value.isNotEmpty)
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedProducts.value.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sel = selectedProducts.value[index];
                      final prod = sel.product;
                      return _SelectedProductChip(
                        product: prod,
                        quantity: sel.quantity,
                        onRemove: () => _removeSelected(prod.productId),
                        onQuantityChanged: (q) => _updateQuantity(prod.productId, q),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 100), // to prevent content underlapping button
            ],
          ),
        ),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: const StadiumBorder(),
              ),
              onPressed: submitting.value ? null : submitOrder,
              child: submitting.value
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text(
                "Add an order",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small horizontal card/pill that shows selected product + qty + remove button.
class _SelectedProductChip extends StatelessWidget {
  final ProductDataModel product;
  final int quantity;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const _SelectedProductChip({
    Key? key,
    required this.product,
    required this.quantity,
    required this.onRemove,
    required this.onQuantityChanged,
  }) : super(key: key);

  String _shortName(String name) {
    if (name.length <= 20) return name;
    return '${name.substring(0, 18)}…';
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF7B8CFF);
    return Card(
      elevation: 2,
      color: AppColors.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 260,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: accent.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: (product.productImage != null &&
                      product.productImage!.isNotEmpty)
                      ? Image.network(
                    '${product.productImage}',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 36),
                  )
                      : Text(
                    product.productName.isNotEmpty ? product.productName[0].toUpperCase() : '—',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortName(product.productName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.sku,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Qty: ', style: TextStyle(color: AppColors.subHeadingTextColor)),
                        Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => onQuantityChanged((quantity - 1).clamp(1, 999999)),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: const Icon(Icons.remove, size: 16),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onQuantityChanged((quantity + 1).clamp(1, 999999)),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

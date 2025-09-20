// edit_product.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/components/status_pill/status_pill.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
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
    final isSaveButtonDisable = useState(true);

    // local editing flag derived from enableSaveNotifier (controls form editability)
    final isEditing = useState<bool>(false);

    final allUsers = useMemoized(() => List.generate(
      30,
          (i) => User(id: '$i', name: 'User $i', email: 'user$i@example.com'),
    ));

    final selected = useState<User?>(null);

    // search function (can be replaced with API call)
    Future<List<User>> searchUsers(String q) async {
      await Future.delayed(Duration(milliseconds: 300)); // simulate latency
      final lower = q.toLowerCase();
      if (q.isEmpty) return allUsers; // return all when empty
      return allUsers.where((u) => u.name.toLowerCase().contains(lower) || u.email.toLowerCase().contains(lower)).toList();
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
                const SizedBox(height: 16.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    spacing: 20,
                    children: [
                      Text("Status"),
                      StatusPill(status: status)
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),

              //   here

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SearchUserDropdown(
                    hintText: 'Search users...',
                    searchFn: searchUsers,
                    onUserSelected: (u) => selected.value = u,
                    maxOverlayHeight: 300,   // <-- adjust overlay max height
                    showAllOnFocus: true,    // <-- show all users when field gains focus
                  ),
                  SizedBox(height: 20),
                  if (selected.value != null) Text('Selected: ${selected.value!.name}'),
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
              onPressed:
                  (loading.value || isSaveButtonDisable.value)
                      ? null
                      : /*onAddProduct*/ null,
              child:
                  loading.value
                      ? const CircularProgressIndicator()
                      : const Text("Save Product"),
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(child: Divider(thickness: 1, color: Colors.grey)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("OR"),
              ),
              Expanded(child: Divider(thickness: 1, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16.0),
          // SizedBox(
          //   width: double.infinity,
          //   child: ElevatedButton(
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: AppColors.deleteButtonColor,
          //       foregroundColor: Colors.white,
          //       minimumSize: const Size(double.infinity, 48),
          //       shape: const StadiumBorder(),
          //     ),
          //     onPressed: deleteLoading.value ? null : onDelete,
          //     child: deleteLoading.value ? const CircularProgressIndicator() : const Text("Delete"),
          //   ),
          // ),
          const SizedBox(height: 80),
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


// edit_product.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/models/product/ProductDeleteResponse.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_request.dart';
import '../../../models/product/product_response.dart';
import '../repository/product_repository.dart';

class EditProduct extends HookWidget {
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

  const EditProduct({
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
    // controllers
    final nameCtrl = useTextEditingController(text: name);
    final descCtrl = useTextEditingController(text: description);
    final skuCtrl = useTextEditingController(text: sku);
    final skuTimestamp = useState<String?>(null);

    final status = useState<String>(this.status);
    final pickedImage = useState<File?>(null);
    final loading = useState<bool>(false);
    final deleteLoading = useState<bool>(false);
    final repo = useMemoized(() => ProductRepository());
    final isSaveButtonDisable = useState(true);

    // local editing flag derived from enableSaveNotifier (controls form editability)
    final isEditing = useState<bool>(false);

    final Map<String, String> roleMap = {
      "Active": "active",
      "Inactive": "inactive",
      "Discontinued": "discontinued",
    };

    List<DropdownMenuItem<String>> dropDownStatus = roleMap.entries
        .map(
          (entry) => DropdownMenuItem<String>(
        value: entry.value,
        child: Text(entry.key),
      ),
    )
        .toList();

    // When enableSaveNotifier changes update local states
    useEffect(() {
      if (enableSaveNotifier != null) {
        void listener() {
          final val = enableSaveNotifier!.value;
          isSaveButtonDisable.value = !val;
          isEditing.value = val;
        }

        // initialize from current notifier value
        isSaveButtonDisable.value = !(enableSaveNotifier!.value);
        isEditing.value = enableSaveNotifier!.value;

        enableSaveNotifier!.addListener(listener);
        return () => enableSaveNotifier!.removeListener(listener);
      } else {
        // if no notifier provided, keep editing disabled by default
        isSaveButtonDisable.value = true;
        isEditing.value = false;
      }
      return null;
    }, [enableSaveNotifier]);

    Future<void> onAddProduct() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product name required')),
        );
        return;
      }

      final sku = skuCtrl.text.trim();
      if (sku.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product SKU required')),
        );
        return;
      }

      loading.value = true;
      try {
        final req = ProductRequest(
          productName: name,
          description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          price: 0,
          stockQuantity: 0,
          sku: sku,
          status: status.value,
          createdByUserId: /* supply current user id if required */ 1,
        );

        final createRes = await repo.updateProduct(req, productId);

        if (createRes is ApiData<ProductResponse>) {
          final productData = createRes.data.data;
          final productId =
          (productData?['productId'] ?? productData?['id']) as int?;
          if (productId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product updated (no id returned)')),
            );
          } else {
            // Upload image if selected
            if (pickedImage.value != null) {
              final upload = await repo.uploadProductImage(productId, pickedImage.value!);
              if (upload is ApiData<ProductResponse>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product updated')),
                );
              } else if (upload is ApiError<ProductResponse>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(upload.message)),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product updated successfully')),
              );
            }
          }
          Navigator.of(context).pop(true);
        } else if (createRes is ApiError<ProductResponse>) {
          final msg = createRes.message;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> onDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete product'),
          content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      deleteLoading.value = true;
      try {
        final res = await repo.deleteProduct(productId);

        if (res is ApiData<ProductDeleteResponse>) {
          final deleteResp = res.data;
          if (deleteResp.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(deleteResp.data?.toString() ?? 'Product deleted successfully')),
            );
            Navigator.of(context).pop(true);
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(deleteResp.error ?? 'Failed to delete product')),
            );
          }
        } else if (res is ApiError<ProductDeleteResponse>) {
          final msg = res.message;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected error while deleting')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      } finally {
        if (Navigator.of(context).mounted) deleteLoading.value = false;
      }
    }

    String sanitizeNameForSku(String name) {
      final sanitized = name
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-');
      return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
    }

    String createTimestampSuffix() {
      final now = DateTime.now();
      final ts =
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      return ts;
    }

    // Listen to name changes to update SKU (existing behavior)
    useEffect(() {
      void listener() {
        final name = nameCtrl.text;
        if (name.trim().isEmpty) {
          skuTimestamp.value = null;
          skuCtrl.text = '';
          return;
        }
        skuTimestamp.value ??= createTimestampSuffix();
        final sanitized = sanitizeNameForSku(name);
        skuCtrl.text = sanitized.isEmpty ? skuTimestamp.value! : '$sanitized-${skuTimestamp.value}';
      }

      nameCtrl.addListener(listener);
      listener();
      return () => nameCtrl.removeListener(listener);
    }, [nameCtrl, skuCtrl, skuTimestamp]);

    // When a picked image changes, set notifier so Save becomes available
    useEffect(() {
      if (pickedImage.value != null && enableSaveNotifier != null) {
        enableSaveNotifier!.value = true;
      }
      return null;
    }, [pickedImage.value]);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          UploadBox(
            imageFile: pickedImage.value,
            onBrowseTap: isEditing.value
                ? () async {
              final res = await FilePicker.platform.pickFiles(type: FileType.image);
              if (res != null && res.files.isNotEmpty && res.files.first.path != null) {
                pickedImage.value = File(res.files.first.path!);
                if (enableSaveNotifier != null) enableSaveNotifier!.value = true;
              }
            }
                : null, // disabled when not editing
          ),
          const SizedBox(height: 20),
          const Divider(),
          Form(
            child: Column(
              children: [
                ProductEditField(
                  text: "Product Name",
                  child: TextFormField(
                    controller: nameCtrl,
                    focusNode: productNameFocusNode,
                    enabled: isEditing.value, // editable only when editing
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0 * 1.5, vertical: 16.0),
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
                    controller: descCtrl,
                    enabled: isEditing.value,
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    keyboardType: TextInputType.multiline,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                    controller: skuCtrl,
                    enabled: false, // SKU remains read-only
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                ProductEditField(
                  text: "Status",
                  child: DropdownButtonFormField<String>(
                    initialValue: status.value,
                    items: dropDownStatus,
                    icon: const Icon(Icons.expand_more),
                    onChanged: isEditing.value ? (value) => status.value = value! : null,
                    style: TextStyle(color: AppColors.subHeadingTextColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Status',
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: (loading.value || isSaveButtonDisable.value) ? null : onAddProduct,
              child: loading.value ? const CircularProgressIndicator() : const Text("Save Product"),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deleteButtonColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: deleteLoading.value ? null : onDelete,
              child: deleteLoading.value ? const CircularProgressIndicator() : const Text("Delete"),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class UploadBox extends StatelessWidget {
  final VoidCallback? onBrowseTap;
  final File? imageFile;

  const UploadBox({super.key, this.imageFile, this.onBrowseTap});

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        color: Colors.grey,
        strokeWidth: 1.5,
        dashPattern: const [6, 3],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageFile != null)
              Image.file(imageFile!, width: 100, height: 100, fit: BoxFit.cover)
            else
              const Icon(Icons.image_outlined, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text("Drop your image here, or ", style: Theme.of(context).textTheme.bodyMedium),
            // disable browse when onBrowseTap == null
            GestureDetector(
              onTap: onBrowseTap,
              child: Text(
                "browse",
                style: TextStyle(
                  color: onBrowseTap != null ? Colors.blueAccent : Colors.grey,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text("Supports: PNG, JPG, JPEG, WEBP", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
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

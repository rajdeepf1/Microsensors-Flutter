import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
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

  const EditProduct({super.key,
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

    final Map<String, String> roleMap = {
      "Active": "active",
      "Inactive": "inactive",
      "Discontinued": "discontinued",
    };

    List<DropdownMenuItem<String>> dropDownStatus =
    roleMap.entries
        .map(
          (entry) => DropdownMenuItem<String>(
        value: entry.value,
        child: Text(entry.key),
      ),
    )
        .toList();

    Future<void> onAddProduct() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product name required')));
        return;
      }

      final sku = skuCtrl.text.trim();
      if (sku.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product SKU required')));
        return;
      }

      loading.value = true;
      try {
        final req = ProductRequest(
          productName: name,
          description:
          descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          price: 0,
          stockQuantity: 0,
          sku: sku,
          status: status.value,
          createdByUserId: /* supply current user id if required */ 1,
        );

        // 1) Create product
        final createRes = await repo.updateProduct(req, productId);

        if (createRes is ApiData<ProductResponse>) {
          final productData = createRes.data.data;
          // read product id returned by backend (adjust key name)
          final productId =
          (productData?['productId'] ?? productData?['id']) as int?;
          if (productId == null) {
            // backend didn't return id — still fine, inform user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product updated (no id returned)')),
            );
          } else {
            // 2) Upload image if selected
            if (pickedImage.value != null) {
              final upload = await repo.uploadProductImage(
                productId,
                pickedImage.value!,
              );
              if (upload is ApiData<ProductResponse>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product updated')),
                );
              } else if (upload is ApiError<ProductResponse>) {
                // show server-provided message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(upload.message ?? 'Image upload failed'),
                  ),
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
          // backend error message (e.g. SKU exists)
          final msg =
              createRes.message ??
                  createRes.error?.toString() ??
                  'Failed to update product';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> onDelete() async {}

    String _sanitizeNameForSku(String name) {
      final sanitized = name
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9 ]'), '') // remove special chars
          .replaceAll(RegExp(r'\s+'), '-')       // spaces -> dashes
          .replaceAll(RegExp(r'-+'), '-');       // collapse repeated dashes
      // optionally truncate if too long
      return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
    }

// helper to create timestamp suffix (human readable)
    String _createTimestampSuffix() {
      final now = DateTime.now();
      final ts = '${now.year.toString().padLeft(4, '0')}' // YYYY
          '${now.month.toString().padLeft(2, '0')}'        // MM
          '${now.day.toString().padLeft(2, '0')}'         // DD
          '-${now.hour.toString().padLeft(2, '0')}'       // HH
          '${now.minute.toString().padLeft(2, '0')}'      // mm
          '${now.second.toString().padLeft(2, '0')}';     // ss
      return ts;
    }

    // listen to name changes and update SKU accordingly
    useEffect(() {
      void listener() {
        final name = nameCtrl.text;
        if (name.trim().isEmpty) {
          // clear both sku and timestamp when name cleared
          skuTimestamp.value = null;
          skuCtrl.text = '';
          return;
        }

        // generate timestamp suffix ONCE when the user *starts* typing
        skuTimestamp.value ??= _createTimestampSuffix();

        // build sku as SANITIZED_NAME - TIMESTAMP
        final sanitized = _sanitizeNameForSku(name);
        skuCtrl.text = sanitized.isEmpty
            ? skuTimestamp.value!
            : '${sanitized}-${skuTimestamp.value}';
      }

      nameCtrl.addListener(listener);
      // initialize in case name already has value
      listener();

      return () => nameCtrl.removeListener(listener);
    }, [nameCtrl, skuCtrl, skuTimestamp]);

    useEffect(() {
      if (enableSaveNotifier != null) {
        void listener() {
          isSaveButtonDisable.value = !enableSaveNotifier!.value;
        }

        enableSaveNotifier!.addListener(listener);
        return () => enableSaveNotifier!.removeListener(listener);
      }
      return null;
    }, [enableSaveNotifier]);

    useEffect(() {
      if (pickedImage.value != null && enableSaveNotifier != null) {
        enableSaveNotifier!.value = true;  // enable save if an image is picked
      }
      return null;
    }, [pickedImage.value]);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(height: 20),
          UploadBox(
            imageFile: pickedImage.value,
            onBrowseTap: () async {
              final res = await FilePicker.platform.pickFiles(type: FileType.image);
              if (res != null && res.files.isNotEmpty && res.files.first.path != null) {
                pickedImage.value = File(res.files.first.path!);
              }
              if (enableSaveNotifier != null) {
                enableSaveNotifier!.value = true;
              }
            },
          ),
          SizedBox(height: 20),
          const Divider(),
          Form(
            child: Column(
              children: [
                ProductEditField(
                  text: "Product Name",
                  child: TextFormField(
                    controller: nameCtrl,
                      focusNode: productNameFocusNode,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
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
                    controller: descCtrl,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    keyboardType: TextInputType.multiline,
                    // tells keyboard it's multiline
                    maxLines: 5,
                    // allows multiple lines
                    minLines: 3,
                    // ensures box has some height
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      alignLabelWithHint: true,
                      // better alignment for multiline
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(
                          Radius.circular(
                            12,
                          ), // softer corners (instead of 50)
                        ),
                      ),
                    ),
                  ),
                ),

                ProductEditField(
                  text: "SKU",
                  child: TextFormField(
                    controller: skuCtrl,
                    enabled: false,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
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
                  text: "Status",
                  child: DropdownButtonFormField(
                    value: status.value,
                    items: dropDownStatus,
                    icon: const Icon(Icons.expand_more),
                    onChanged: (value) => status.value = value!,
                    style: TextStyle(
                      color: AppColors.sub_heading_text_color,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Status',
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5,
                        vertical: 16.0,
                      ),
                      border: OutlineInputBorder(
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
              child:
              loading.value
                  ? const CircularProgressIndicator()
                  : const Text("Save Product"),
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.text_color,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.delete_button_color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: deleteLoading.value ? null : onDelete,
              child:
              deleteLoading.value
                  ? const CircularProgressIndicator()
                  : const Text("Delete"),
            ),
          ),
          SizedBox(height: 80),
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
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      color: Colors.grey,
      strokeWidth: 1.5,
      dashPattern: const [6, 3],
      // dash style
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upload icon
            if (imageFile != null)
              Image.file(
                imageFile!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              )
            else
              const Icon(Icons.image_outlined,
                  size: 60, color: Colors.blueAccent),

            const SizedBox(height: 12),

            // Main text
            Text(
              "Drop your image here, or ",
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            // Browse link
            GestureDetector(
              onTap: onBrowseTap,
              child: Text(
                "browse",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Supported formats
            const Text(
              "Supports: PNG, JPG, JPEG, WEBP",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium, // optional styling
          ),
          const SizedBox(height: 8), // spacing
          child,
        ],
      ),
    );
  }
}
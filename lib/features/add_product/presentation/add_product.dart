import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../core/api_state.dart';
import '../../../models/product/product_request.dart';
import '../../../models/product/product_response.dart';
import '../../components/quantity_edit_text/QuantityField.dart';
import '../repository/product_repository.dart';

class AddProduct extends HookWidget {
  const AddProduct({super.key});

  @override
  Widget build(BuildContext context) {
    // controllers
    final nameCtrl = useTextEditingController();
    final descCtrl = useTextEditingController();
    final priceCtrl = useTextEditingController();
    final skuCtrl = useTextEditingController();
    final skuTimestamp = useState<String?>(null);

    final qty = useState<int>(0);
    final status = useState<bool>(true); // true -> ACTIVE
    final pickedImage = useState<File?>(null);
    final loading = useState<bool>(false);
    final repo = useMemoized(() => ProductRepository());
    final isSwitched = useState(true);

    Future<void> browseImage() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      pickedImage.value = File(path);
    }

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
          price: null,
          stockQuantity: 0,
          sku: sku,
          status: status.value ? 'ACTIVE' : 'INACTIVE',
          createdByUserId: /* supply current user id if required */ 1,
        );

        // 1) Create product
        final createRes = await repo.createProduct(req);

        if (createRes is ApiData<ProductResponse>) {
          final productData = createRes.data.data;
          // read product id returned by backend (adjust key name)
          final productId =
              (productData?['productId'] ?? productData?['id']) as int?;
          if (productId == null) {
            // backend didn't return id — still fine, inform user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product created (no id returned)')),
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
                  const SnackBar(content: Text('Product created')),
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
                const SnackBar(content: Text('Product created successfully')),
              );
            }
          }
          context.pop();
        } else if (createRes is ApiError<ProductResponse>) {
          // backend error message (e.g. SKU exists)
          final msg =
              createRes.message ??
              createRes.error?.toString() ??
              'Failed to create product';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        loading.value = false;
      }
    }

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

    return MainLayout(
      title: "Add Product",
      child: SingleChildScrollView(
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

                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: ProductEditField(
                  //         text: "Product Price",
                  //         child: TextFormField(
                  //           controller: priceCtrl,
                  //           keyboardType: TextInputType.number,
                  //           style: TextStyle(
                  //             color: AppColors.sub_heading_text_color,
                  //           ),
                  //           decoration: InputDecoration(
                  //             prefixText: "₹ ",
                  //             prefixStyle: TextStyle(color: AppColors.sub_heading_text_color),
                  //             filled: true,
                  //             fillColor: AppColors.app_blue_color.withOpacity(
                  //               0.05,
                  //             ),
                  //             contentPadding: const EdgeInsets.symmetric(
                  //               horizontal: 16.0 * 1.5,
                  //               vertical: 16.0,
                  //             ),
                  //             border: const OutlineInputBorder(
                  //               borderSide: BorderSide.none,
                  //               borderRadius: BorderRadius.all(
                  //                 Radius.circular(50),
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16), // spacing between fields
                  //     Expanded(
                  //       child: QuantityField(
                  //         label: "Stock Qty",
                  //         initialValue: 0,
                  //         onChanged: (val) {
                  //           print("Quantity updated: $val");
                  //           qty.value = val;
                  //         },
                  //       ),
                  //     ),
                  //   ],
                  // ),

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

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16.0 * 1.5,
                    ),
                    child: Row(
                      spacing: 16,
                      children: [
                        Text("Active Status"),

                        Switch(
                          value: isSwitched.value,
                          onChanged: (val) => isSwitched.value = val,
                          activeThumbColor: Colors.green,
                          activeTrackColor: Colors.greenAccent,
                          // track color when ON
                          inactiveThumbColor: AppColors.app_blue_color,
                          // thumb color when OFF
                          inactiveTrackColor: AppColors.app_blue_color
                              .withOpacity(0.05),
                          // track color when OFF
                          trackOutlineColor: MaterialStateProperty.all(
                            AppColors.app_blue_color.withOpacity(0.05),
                          ),
                        ),
                      ],
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
                onPressed: loading.value ? null : onAddProduct,
                child:
                loading.value
                    ? const CircularProgressIndicator()
                    : const Text("Add Product"),
              ),
            ),
            SizedBox(height: 80),
          ],
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../components/quantity_edit_text/QuantityField.dart';

class AddProduct extends HookWidget {
  const AddProduct({super.key});

  @override
  Widget build(BuildContext context) {
    final isSwitched = useState(true);

    return MainLayout(
      title: "Add Product",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            UploadBox(
              onBrowseTap: () {
                print("Browse tapped");
                // open file picker here
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
                      initialValue: "",
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
                      initialValue: "",
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

                  Row(
                    children: [
                      Expanded(
                        child: ProductEditField(
                          text: "Product Price",
                          child: TextFormField(
                            style: TextStyle(
                              color: AppColors.sub_heading_text_color,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.app_blue_color.withOpacity(
                                0.05,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0 * 1.5,
                                vertical: 16.0,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(50),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // spacing between fields
                      Expanded(
                        child:QuantityField(
                          label: "Stock Qty",
                          initialValue: 0,
                          onChanged: (val) {
                            print("Quantity updated: $val");
                          },
                        ),

                      ),
                    ],
                  ),

                  ProductEditField(
                    text: "SKU",
                    child: TextFormField(
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
                    padding: const EdgeInsets.symmetric(vertical: 16,horizontal: 16.0 * 1.5),
                    child: Row(
                      spacing: 16,
                      children: [
                        Text(isSwitched.value ? "Active" : "InActive"),

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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).textTheme.bodyLarge!.color!.withOpacity(0.08),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 16.0),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {},
                    child: const Text("Add Product"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 80,)
          ],
        ),
      ),
    );
  }
}

class UploadBox extends StatelessWidget {
  final VoidCallback? onBrowseTap;

  const UploadBox({super.key, this.onBrowseTap});

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
            Icon(Icons.image_outlined, size: 60, color: Colors.blueAccent),

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

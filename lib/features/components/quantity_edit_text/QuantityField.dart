import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../utils/colors.dart';
import '../../add_product/presentation/add_product.dart';

class QuantityField extends HookWidget {
  final String label;
  final int initialValue;
  final ValueChanged<int>? onChanged;

  const QuantityField({
    super.key,
    required this.label,
    this.initialValue = 0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final qty = useState(initialValue);
    final controller = useTextEditingController(text: qty.value.toString());

    void updateValue(int newVal) {
      if (newVal < 0) return; // prevent negative qty
      qty.value = newVal;
      controller.text = newVal.toString();
      if (onChanged != null) onChanged!(newVal);
    }

    return ProductEditField(
      text: label,
      child: TextFormField(
        controller: controller,
        readOnly: true, // user can only change via buttons
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.headingTextColor),
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => updateValue(qty.value - 1),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => updateValue(qty.value + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

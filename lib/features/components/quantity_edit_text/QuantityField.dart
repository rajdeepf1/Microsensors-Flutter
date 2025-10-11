import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';

import '../../../utils/colors.dart';
import '../../add_product/presentation/add_product.dart';

/// Compact QuantityField with optional label.
/// Left-aligned text, compact +/- buttons on the right, no overflow.
class QuantityField extends HookWidget {
  final String? label;
  final Color? qytFillColor;
  final int initialValue;
  final ValueChanged<int>? onChanged;

  const QuantityField({
    super.key,
    this.label,
    this.qytFillColor,
    this.initialValue = 0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final qty = useState<int>(initialValue.clamp(0, 9999999));
    final controller = useTextEditingController(text: qty.value.toString());
    final focusNode = useFocusNode();

    // Keep controller and qty in sync when user types
    useEffect(() {
      void listener() {
        final text = controller.text.trim();
        final parsed = int.tryParse(text) ?? 0;
        if (parsed != qty.value) {
          qty.value = parsed;
          onChanged?.call(parsed);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    void updateValue(int newVal) {
      newVal = newVal.clamp(0, 9999999);
      if (newVal == qty.value) return;
      qty.value = newVal;
      controller.text = newVal.toString();
      controller.selection =
          TextSelection.collapsed(offset: controller.text.length);
      onChanged?.call(newVal);
    }

    // The compact suffix (two small buttons) — constrained to avoid overflow
    final Widget suffix = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 0,
        maxWidth: 68, // keeps the suffix compact horizontally
        maxHeight: 40, // must be <= field height to avoid vertical overflow
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _smallBtn(Icons.remove, () => updateValue(qty.value - 1)),
              const SizedBox(width: 6),
              _smallBtn(Icons.add, () => updateValue(qty.value + 1)),
            ],
          ),
        ),
      ),
    );

    final textField = SizedBox(
      height: 40, // adjust field height if you need larger touch targets
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.start,
        maxLength: 6,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7),
        ],
        style: TextStyle(
          color: AppColors.headingTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: qytFillColor ?? AppColors.appBlueColor.withValues(alpha: 0.05),
          isDense: true,
          // left padding small, right padding zero so text hugs suffix
          contentPadding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
          // Allow very small suffix box and prevent it from growing
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
            maxWidth: 68,
            maxHeight: 40,
          ),
          suffixIcon: suffix,
        ),
        onFieldSubmitted: (_) {
          final val = int.tryParse(controller.text.trim()) ?? 0;
          updateValue(val);
        },
      ),
    );

    // If label present wrap in ProductEditField, otherwise return field directly
    if (label != null && label!.isNotEmpty) {
      return ProductEditField(text: label!, child: textField);
    }

    return textField;
  }

  /// Small compact button implemented with GestureDetector + Container
  /// to avoid IconButton's extra padding and to ensure fixed small size.
  Widget _smallBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        // optional subtle hit/background - keep minimal
        // decoration: BoxDecoration(
        //   color: Colors.transparent,
        //   borderRadius: BorderRadius.circular(6),
        // ),
        child: Icon(icon, size: 14, color: AppColors.headingTextColor),
      ),
    );
  }
}

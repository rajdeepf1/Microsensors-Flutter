import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';

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
    final qty = useState<int>(initialValue.clamp(0, 9999999));
    final controller = useTextEditingController(text: qty.value.toString());
    final focusNode = useFocusNode();

    // Keep controller and qty in sync when user types
    useEffect(() {
      void listener() {
        final text = controller.text.trim();

        if (text.isEmpty) {
          if (qty.value != 0) {
            qty.value = 0;
            onChanged?.call(0);
          }
          return;
        }

        final parsed = int.tryParse(text);
        if (parsed == null) {
          // shouldn't happen due to inputFormatter but ignore if it does
          return;
        }

        final clamped = parsed.clamp(0, 9999999);
        if (clamped != qty.value) {
          qty.value = clamped;
          onChanged?.call(clamped);
        }
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    void updateValue(int newVal) {
      if (newVal < 0) return;
      newVal = newVal.clamp(0, 9999999);
      if (newVal == qty.value) return;
      qty.value = newVal;
      // update controller and move cursor to end
      controller.text = newVal.toString();
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      onChanged?.call(newVal);
    }

    return ProductEditField(
      text: label,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        readOnly: false,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters:  [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7), // optional max digits
        ],
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.headingTextColor),
        // Ensure tapping the field always requests focus (helps if a parent widget intercepts taps)
        onTap: () {
          if (!focusNode.hasFocus) {
            FocusScope.of(context).requestFocus(focusNode);
          }
        },
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
          // allow the suffix to be as small as we want (no extra InputDecorator padding)
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          // Give the suffix area enough width so the two buttons + any internal padding don't overflow
          suffixIcon: SizedBox(
            width: 104, // <-- widen this if you use larger touch targets
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  // compact but still accessible 44x44 touch target
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => updateValue(qty.value - 1),
                  tooltip: 'Decrease',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => updateValue(qty.value + 1),
                  tooltip: 'Increase',
                ),
              ],
            ),
          ),
        ),
        // normalize when user finishes typing
        onFieldSubmitted: (_) {
          final t = controller.text.trim();
          if (t.isEmpty) {
            updateValue(0);
          } else {
            final parsed = int.tryParse(t);
            if (parsed != null) updateValue(parsed);
          }
        },
      ),
    );
  }
}

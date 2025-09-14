import 'package:flutter/material.dart';
import 'package:microsensors/utils/colors.dart';

class StatusPill extends StatelessWidget {
  final String status; // "active", "inactive", "discontinued"
  final double? height;

  const StatusPill({
    super.key,
    required this.status,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();

    late final String label;
    late final Color bg;
    late final Color textColor;
    late final Color borderColor;

    switch (normalized) {
      case 'active':
        label = 'Active';
        bg = AppColors.pill_active_bg_color;
        textColor = AppColors.pill_active_text_color;
        borderColor = const Color(0xFFB7E5C9);
        break;

      case 'discontinued':
        label = 'Discontinued';
        bg = AppColors.pill_discontinued_bg_color;
        textColor = AppColors.pill_discontinued_text_color;
        borderColor = Colors.black54;
        break;

      case 'inactive':
      default:
        label = 'Inactive';
        bg = AppColors.pill_in_active_bg_color;
        textColor = AppColors.pill_in_active_text_color;
        borderColor = const Color(0xFFF5C6C6);
        break;
    }

    return Container(
      height: height ?? 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

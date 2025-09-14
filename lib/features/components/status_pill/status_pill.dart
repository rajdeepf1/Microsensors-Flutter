// Add this small reusable widget somewhere (same file or a shared widgets file)
import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  final bool active;
  final double? height;

  const StatusPill({super.key, required this.active, this.height});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFE6F7EC) : const Color(0xFFFEEFEF);
    final textColor = active ? const Color(0xFF0F9D58) : const Color(0xFFB91C1C);
    final label = active ? 'Active' : 'Inactive';

    return Container(
      height: height ?? 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFFB7E5C9) : const Color(0xFFF5C6C6)),
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

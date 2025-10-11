import 'package:flutter/material.dart';

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
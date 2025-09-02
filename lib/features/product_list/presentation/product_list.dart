import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';

import '../../../utils/colors.dart';

class ProductList extends StatelessWidget {
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(title: "Products", child: Text("Products"));
  }
}

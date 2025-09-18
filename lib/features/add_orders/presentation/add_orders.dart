import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';

class AddOrders extends HookWidget {
  const AddOrders({super.key});

  @override
  Widget build(BuildContext context) {

    return MainLayout(title: "Add Orders", child: Text("Add Orders"));
  }



}



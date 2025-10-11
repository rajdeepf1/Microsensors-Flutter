import 'package:microsensors/models/product/product_list_response.dart';

class SelectedProducts {
  final ProductDataModel product;
  final int quantity;

  SelectedProducts({
    required this.product,
    required this.quantity,
  });

}

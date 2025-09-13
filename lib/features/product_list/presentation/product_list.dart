
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/product_list/repository/product_repository.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../components/main_layout/main_layout.dart';

class ProductList extends HookWidget {
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    final apiState = useState<ApiState<List<ProductDataModel>>>(const ApiInitial());
    final repo = useMemoized(() => ProductRepository());

    Future<void> loadProducts() async {
      apiState.value = const ApiLoading();
      final result = await repo.fetchProducts();
      apiState.value = result;
    }

    useEffect(() {
      loadProducts();
      return null;
    }, const []);

    Widget body;

    if (apiState.value is ApiInitial || apiState.value is ApiLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (apiState.value is ApiError<List<ProductDataModel>>) {
      final err = apiState.value as ApiError<List<ProductDataModel>>;
      body = _RetryView(message: err.message, onRetry: loadProducts);
    } else if (apiState.value is ApiData<List<ProductDataModel>>) {
      final products = (apiState.value as ApiData<List<ProductDataModel>>).data;
      if (products.isEmpty) {
        body = _RetryView(message: 'No products found', onRetry: loadProducts);
      } else {
        body = ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final p = products[index];
            final avatarUrl = p.productImage;
            return ProductCardWidget(
              name: p.productName,
              description: p.description,
              price: p.price,
              stockQuantity: p.stockQuantity,
              sku: p.sku,
              status: p.status,
              createdBy: p.createdByUsername,
              createdAt: p.formattedCreatedAt,
              avatarUrl: avatarUrl!,
            );
          },
        );
      }
    } else {
      body = const Center(child: Text('Unknown state'));
    }

    return Scaffold(
      body: MainLayout(title: "Products", child: SafeArea(child: body)),
    );
  }

}

class _RetryView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _RetryView({required this.message, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}



class ProductCardWidget extends StatelessWidget {
  final String name;
  final String description;
  final double price;
  final int stockQuantity;
  final String sku;
  final String status;
  final String createdBy;
  final String createdAt;
  final String avatarUrl;

  const ProductCardWidget({
    super.key,
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.sku,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final stockText =
    stockQuantity > 0 ? 'In stock: $stockQuantity' : 'Out of stock';

    return Card(
      elevation: 4,
      color: AppColors.card_color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full width image with overlay name
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 180, // fixed height (adjust as needed)
                  child: SmartImage(
                    imageUrl: avatarUrl,
                    baseUrl: Constants.apiBaseUrl,
                    shape: ImageShape.rectangle,
                    fit: BoxFit.cover, // image covers full width
                    // placeholder: Image.asset("assets/images/auth_image.png",
                    //     fit: BoxFit.cover),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.black54,
                  padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Product details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6), // space around text
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, // background color
                    borderRadius: BorderRadius.circular(6), // rounded corners
                  ),
                  child: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87, // text color
                      fontSize: 14,
                    ),
                  ),
                ),



                const SizedBox(height: 8),



                Row(
                  children: [
                    Expanded(child: Text('Price: ₹${price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),),
                    Expanded(child: Text(stockText,
                        style: TextStyle(
                            color:
                            stockQuantity > 0 ? Colors.green : Colors.red)),),
                    Expanded(child:                status=='active'? Text('Status: $status',style: TextStyle(color: Colors.green),) :Text('Status: $status',style: TextStyle(color: Colors.red)),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                Text('SKU: $sku', style: const TextStyle(color: Colors.grey,fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Created by: $createdBy',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Created at: ${createdAt}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





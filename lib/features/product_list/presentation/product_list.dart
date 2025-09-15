import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/components/status_pill/status_pill.dart';
import 'package:microsensors/features/product_list/presentation/edit_product.dart';
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
    final apiState = useState<ApiState<List<ProductDataModel>>>(
      const ApiInitial(),
    );
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
              productId: p.productId,
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
  final int productId;
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
    required this.productId,
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

  void _openDetailsSheet(BuildContext context) {

    final FocusNode productNameFocusNode = FocusNode();
    final enableSaveNotifier = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allows full-screen height
      backgroundColor: Colors.transparent, // to apply rounded corners easily
      builder: (BuildContext ctx) {
        // Use FractionallySizedBox to control sheet height (0.95 -> ~full-screen)
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Material(
              // Material so AppBar / buttons use Material styles
              color: Colors.white,
              child: SafeArea(
                top: false,
                // keep top as part of the sheet (AppBar handles status)
                child: Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.white,
                    iconTheme: const IconThemeData(color: Colors.black),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.black),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.black),
                          tooltip: "Edit",
                          onPressed: () {
                            // TODO: handle edit action here
                            debugPrint("Edit button clicked for $name");
                            productNameFocusNode.requestFocus();
                            enableSaveNotifier.value = true;
                          },
                        ),
                      ),
                    ],

                  ),
                  body: EditProduct(
                    productId: productId,
                    name: name,
                    description: description,
                    sku: sku,
                    status: status,
                    createdBy: createdBy,
                    createdAt: createdAt,
                    avatarUrl: avatarUrl,
                    productNameFocusNode: productNameFocusNode,
                    enableSaveNotifier: enableSaveNotifier,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

  }

  @override
  Widget build(BuildContext context) {
    final cardBg = AppColors.card_color;
    final accent = const Color(0xFF7B8CFF);
    final titleColor = const Color(0xFF1B1140);
    final subtitleColor = Colors.black54;

    return Card(
      elevation: 2,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(width: 100, child: StatusPill(status: status)),
                  const SizedBox(height: 10),

                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'SKU: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: sku,
                          style: TextStyle(
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),

                  const SizedBox(height: 10),


                  Text(
                    createdAt,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                  const SizedBox(height: 20),

                  // Details button — opens sheet
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: () => _openDetailsSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Details \u2192',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right image box
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                color: accent.withOpacity(0.12),
                child: SmartImage(
                  imageUrl: avatarUrl,
                  baseUrl: Constants.apiBaseUrl,
                  width: 120,
                  height: 120,
                  shape: ImageShape.rectangle,
                  fit: BoxFit.cover,
                  username: name,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

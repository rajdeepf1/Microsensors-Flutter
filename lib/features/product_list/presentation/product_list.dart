// lib/features/product_list/presentation/product_list.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/components/status_pill/status_pill.dart';
import 'package:microsensors/features/product_list/presentation/edit_product.dart';
import 'package:microsensors/features/product_list/repository/product_repository.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../components/main_layout/main_layout.dart';
import '../../sales_user_dashboard/repository/sales_dashboard_repository.dart';

class ProductList extends HookWidget {
  const ProductList({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => ProductRepository());

    const int pageSize = 20;
    const int initialPage = 0;

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>('');
    final debounceRef = useRef<Timer?>(null);
    final dateRange = useState<DateTimeRange?>(null);

    String? _normalizeSearch(String? q) {
      if (q == null) return null;
      final t = q.trim();
      return t.isEmpty ? null : t;
    }

    String? _formatDateForApi(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }


    final pagingController = useMemoized(
          () => PagingController<int, ProductDataModel>(
        getNextPageKey: (PagingState<int, ProductDataModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return initialPage;

          final lastKey = (state.keys?.isNotEmpty ?? false)
              ? state.keys!.last
              : (initialPage + state.pages!.length - 1);

          if (totalPages.value != null && lastKey >= (totalPages.value! - 1)) {
            return null;
          }

          return lastKey + 1;
        },
        fetchPage: (int pageKey) async {
          debugPrint('Products.fetchPage: page=$pageKey, q="${searchQuery.value}"');

          final res = await repo.fetchProductsPage(
            page: pageKey,
            pageSize: pageSize,
            search: _normalizeSearch(searchQuery.value),
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
          );

          if (res is ApiError<ProductPageResult>) {
            throw Exception(res.message);
          }

          if (res is ApiData<ProductPageResult>) {
            final pageResult = res.data;
            final items = pageResult.items;
            final total = pageResult.total ?? 0;

            if (totalPages.value == null) {
              totalPages.value =
              total > 0 ? ((total + pageSize - 1) ~/ pageSize) : 0;
              debugPrint('Products: totalPages=${totalPages.value}, total=$total');
            }

            return items;
          }

          return <ProductDataModel>[];
        },
      ),
      [repo, searchQuery.value, dateRange.value],
    );


    void _onDateRangeChanged(DateTimeRange? picked) {
      dateRange.value = picked;
      totalPages.value = null;
      try {
        pagingController.refresh();
      } catch (_) {}
    }

    useEffect(() {
      try {
        pagingController.fetchNextPage();
      } catch (_) {
        try {
          pagingController.refresh();
        } catch (_) {}
      }

      return () {
        debounceRef.value?.cancel();
        try {
          pagingController.dispose();
        } catch (_) {}
      };
    }, [pagingController]);

    void onSearchChanged(String q) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(const Duration(milliseconds: 400), () {
        final trimmed = q.trim();
        if (trimmed == searchQuery.value) return;

        searchQuery.value = trimmed;
        totalPages.value = null;

        try {
          pagingController.refresh();
        } catch (_) {}
      });
    }

    return MainLayout(
      title: "Products",
      screenType: ScreenType.search_calender,
      onSearchChanged: onSearchChanged,
      onDateRangeChanged: _onDateRangeChanged,
      child: PagingListener<int, ProductDataModel>(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          if (state.isLoading && (state.pages?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && (state.pages?.isEmpty ?? true)) {
            return Center(
              child: ElevatedButton(
                onPressed: () => fetchNextPage(),
                child: const Text('Retry'),
              ),
            );
          }

          if (state.pages?.isEmpty ?? true) {
            return const Center(child: Text('No products found'));
          }

          return SafeArea(
            top: false,   // MainLayout already handles top/appbar
            bottom: true, // protect from home indicator / gesture area
            child:
          PagedListView<int, ProductDataModel>(
            state: state,
            fetchNextPage: fetchNextPage,
            padding: const EdgeInsets.all(16),
            builderDelegate: PagedChildBuilderDelegate<ProductDataModel>(
              itemBuilder: (context, product, index) {
                final p = product;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ProductCardWidget(
                    productId: p.productId,
                    name: p.productName,
                    description: p.description,
                    price: p.price,
                    stockQuantity: p.stockQuantity,
                    sku: p.sku,
                    status: p.status,
                    createdBy: p.createdByUsername,
                    createdAt: p.formattedCreatedAt,
                    avatarUrl: p.productImage,
                    onRefresh: () async {
                      totalPages.value = null;
                      try {
                        pagingController.refresh();
                      } catch (_) {}
                    },
                  ),
                );
              },
              firstPageProgressIndicatorBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
              firstPageErrorIndicatorBuilder: (_) => Center(
                child: ElevatedButton(
                  onPressed: () => fetchNextPage(),
                  child: const Text('Retry'),
                ),
              ),
              noItemsFoundIndicatorBuilder: (_) =>
              const Center(child: Text('No products found')),
              noMoreItemsIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('No more products')),
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}

/// ProductCardWidget (kept same as your original, only onRefresh is wired)
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
  final String? avatarUrl;
  final Future<void> Function()? onRefresh;

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
    this.onRefresh,
  });

  void _openDetailsSheet(BuildContext context) async {
    final FocusNode productNameFocusNode = FocusNode();
    final enableSaveNotifier = ValueNotifier<bool>(false);

    final bool? result = await showModalBottomSheet(
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
                    avatarUrl: avatarUrl ?? "",
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

    if (result == true) {
      await onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = AppColors.cardColor;
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
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: sku,
                          style: TextStyle(color: subtitleColor),
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
                color: accent.withValues(alpha: 0.12),
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

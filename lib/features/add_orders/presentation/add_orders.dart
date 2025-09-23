// lib/features/products/presentation/add_orders.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/add_orders/presentation/product_details.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/utils/constants.dart';

import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../../utils/colors.dart';
import '../../components/status_pill/status_pill.dart';
import '../repository/product_list_repository.dart';

class AddOrders extends HookWidget {
  const AddOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => SalesProductListRepository());
    const int pageSize = 20;

    final totalPages = useState<int?>(null);
    final searchQuery = useState<String>("");
    final debounceRef = useRef<Timer?>(null);

    // paging controller: v5 constructor requires getNextPageKey and fetchPage
    final pagingController = useMemoized(
          () => PagingController<int, ProductDataModel>(
        // next-key logic based on current PagingState
        getNextPageKey: (PagingState<int, ProductDataModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return 1;
          final lastKey = (state.keys?.isNotEmpty ?? false) ? state.keys!.last : state.pages!.length;
          if (totalPages.value != null && lastKey >= totalPages.value!) return null;
          return lastKey + 1;
        },

        // fetchPage MUST return FutureOr<List<ProductDataModel>>
        fetchPage: (int pageKey) async {
          debugPrint('fetchPage called: page=$pageKey, search="${searchQuery.value}"');
          final result = await repo.fetchProductsPage(
            page: pageKey,
            pageSize: pageSize,
            search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
          );

          if (result is ApiError<ProductPageResult>) {
            // throw to let the library know there was an error
            throw Exception(result.message);
          }

          if (result is ApiData<ProductPageResult>) {
            final pageResult = result.data;

            // compute and store totalPages (once)
            if (pageResult.total != null && totalPages.value == null) {
              totalPages.value = (pageResult.total! + pageSize - 1) ~/ pageSize;
              debugPrint("✅ totalPages = ${totalPages.value}, total = ${pageResult.total}");
            }

            debugPrint("📦 fetchPage: page=$pageKey, items=${pageResult.items.length}");
            // return the items for this page
            return pageResult.items;
          }

          // fallback: empty list
          return <ProductDataModel>[];
        },
      ),
      // recreate controller when repo or searchQuery changes so new query starts fresh
      [repo, searchQuery.value],
    );

    // When the controller is created/recreated, refresh first page and ensure dispose
    useEffect(() {
      // trigger initial load
      try {
        pagingController.fetchNextPage();
      } catch (_) {
        // fetchNextPage might not exist on this controller style: the library should call fetchPage internally.
        // To be safe call refresh() if available:
        try {
          pagingController.refresh();
        } catch (_) {}
      }

      return () {
        debounceRef.value?.cancel();
        pagingController.dispose();
      };
    }, [pagingController]);

    // Debounced search callback to be passed to MainLayout
    void onSearchChanged(String q) {
      debounceRef.value?.cancel();
      debounceRef.value = Timer(const Duration(milliseconds: 400), () {
        final trimmed = q.trim();
        if (trimmed == searchQuery.value) return;
        searchQuery.value = trimmed;
        totalPages.value = null;
        // recreate controller (because useMemoized deps include searchQuery.value) — but also refresh current one
        try {
          pagingController.refresh();
        } catch (_) {}
      });
    }

    return MainLayout(
      title: "Add Orders",
      screenType: ScreenType.search,
      onSearchChanged: onSearchChanged, // wire up the AppBar textfield -> this callback
      child: PagingListener<int, ProductDataModel>(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          // debug info
          debugPrint('builder: pages=${state.pages?.length}, isLoading=${state.isLoading}, hasNext=${state.hasNextPage}');

          if (state.isLoading && (state.pages?.isEmpty ?? true)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && (state.pages?.isEmpty ?? true)) {
            return Center(
              child: ElevatedButton(
                onPressed: () => fetchNextPage(), // retry
                child: const Text("Retry"),
              ),
            );
          }

          if (state.pages?.isEmpty ?? true) {
            return const Center(child: Text("No products found"));
          }

          return PagedListView<int, ProductDataModel>(
            // builder-style API requires state & fetchNextPage
            state: state,
            fetchNextPage: fetchNextPage,
            padding: const EdgeInsets.all(16),
            builderDelegate: PagedChildBuilderDelegate<ProductDataModel>(
              itemBuilder: (context, product, index) {
                return ProductCardWidget(
                  productId: product.productId,
                  name: product.productName,
                  description: product.description,
                  sku: product.sku,
                  avatarUrl: product.productImage,
                  createdAt: product.createdAt,
                  status: product.status,
                  createdBy: product.createdByUsername,
                );
              },
              firstPageProgressIndicatorBuilder: (_) => const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder: (_) => const Center(child: CircularProgressIndicator()),
              noItemsFoundIndicatorBuilder: (_) => const Center(child: Text("No products found")),
              noMoreItemsIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text("No more products")),
              ),
              firstPageErrorIndicatorBuilder: (_) => Center(
                child: ElevatedButton(
                  onPressed: () => fetchNextPage(),
                  child: const Text("Retry"),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductCardWidget extends StatelessWidget {
  final int productId;
  final String name;
  final String description;
  final String sku;
  final String? avatarUrl; // nullable now
  final String createdAt;
  final String status;
  final String createdBy;

  const ProductCardWidget({
    super.key,
    required this.productId,
    required this.name,
    required this.description,
    required this.sku,
    required this.avatarUrl,
    required this.createdAt,
    required this.status,
    required this.createdBy,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = AppColors.cardColor;
    final accent = const Color(0xFF7B8CFF);
    final titleColor = const Color(0xFF1B1140);
    final subtitleColor = Colors.black54;

    // friendly short date (attempt to parse — fallback to raw string)
    String formattedDate(String raw) {
      if (raw.isEmpty) return '';
      try {
        final dt = DateTime.tryParse(raw);
        if (dt == null) return raw;
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return raw;
      }
    }

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
                    ),
                    body: SalesProductDetails(
                      productId: productId,
                      name: name,
                      description: description,
                      sku: sku,
                      status: status,
                      createdBy: createdBy,
                      createdAt: createdAt,
                      avatarUrl: avatarUrl??"",
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
        //await onRefresh?.call();
      }
    }


    return Card(
      elevation: 2,
      color: cardBg,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                    formattedDate(createdAt),
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: () {_openDetailsSheet(context);},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Details \u2192', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? SmartImage(
                  imageUrl: avatarUrl,
                  baseUrl: Constants.apiBaseUrl,
                  width: 120,
                  height: 120,
                  shape: ImageShape.rectangle,
                  fit: BoxFit.cover,
                  username: name,
                )
                    : _placeholderAvatar(name, 120, 120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simple placeholder that uses initials when there's no image
  Widget _placeholderAvatar(String name, double w, double h) {
    String initials = '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      initials = parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();
    }
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : '—',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
      ),
    );
  }
}

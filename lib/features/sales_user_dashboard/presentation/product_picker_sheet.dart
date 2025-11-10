import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/features/sales_user_dashboard/repository/sales_dashboard_repository.dart';
import 'package:microsensors/utils/constants.dart';
import '../../../core/api_state.dart';
import '../../../models/product/product_list_response.dart';
import '../../../models/product/selected_products.dart';
import '../../../utils/colors.dart';
import '../../components/quantity_edit_text/QuantityField.dart';

/// Hook-based full-height product picker sheet with multi-select checkboxes.
/// Returns List<ProductDataModel> when saved (or null if cancelled).
class ProductPickerSheet extends HookWidget {
  final int pageSize;
  final String title;
  final bool clearOnOpen;

  const ProductPickerSheet({
    Key? key,
    this.pageSize = 20,
    this.title = 'Add products',
    this.clearOnOpen = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => SalesDashboardRepository());

    final totalPages = useState<int?>(null);
    final selectedIds = useState<Set<int>>(<int>{});
    final selectedMap = useState<Map<int, ProductDataModel>>(
      <int, ProductDataModel>{},
    );

    final quantities = useState<Map<int, int>>(<int, int>{});

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

    String _formatDate(String raw) {
      if (raw.isEmpty) return '';
      try {
        final dt = DateTime.tryParse(raw);
        if (dt == null) return raw;
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return raw;
      }
    }

    // Paging controller
    final pagingController = useMemoized(
      () => PagingController<int, ProductDataModel>(
        getNextPageKey: (PagingState<int, ProductDataModel> state) {
          if (state.pages == null || state.pages!.isEmpty) return 1;
          final lastKey =
              (state.keys?.isNotEmpty ?? false)
                  ? state.keys!.last
                  : state.pages!.length;
          if (totalPages.value != null && lastKey >= totalPages.value!)
            return null;
          return lastKey + 1;
        },
        fetchPage: (int pageKey) async {
          debugPrint(
            'fetchPage called: page=$pageKey, search="${searchQuery.value}", dateRange=${dateRange.value}',
          );

          final result = await repo.fetchProductsPage(
            page: pageKey,
            pageSize: pageSize,
            search:
                searchQuery.value.isNotEmpty
                    ? _normalizeSearch(searchQuery.value)
                    : null,
            dateFrom: _formatDateForApi(dateRange.value?.start),
            dateTo: _formatDateForApi(dateRange.value?.end),
          );

          if (result is ApiError<ProductPageResult>) {
            throw Exception(result.message);
          }

          if (result is ApiData<ProductPageResult>) {
            final pageResult = result.data;
            if (pageResult.total != null && totalPages.value == null) {
              totalPages.value = (pageResult.total! + pageSize - 1) ~/ pageSize;
              debugPrint(
                "✅ totalPages = ${totalPages.value}, total = ${pageResult.total}",
              );
            }

            debugPrint(
              "📦 fetchPage: page=$pageKey, items=${pageResult.items.length}",
            );
            return pageResult.items;
          }

          return <ProductDataModel>[];
        },
      ),
      [repo, searchQuery.value, dateRange.value],
    );

    // initial load + cleanup
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          pagingController.fetchNextPage();
        } catch (_) {
          try {
            pagingController.refresh();
          } catch (_) {}
        }
      });

      return () {
        debounceRef.value?.cancel();
        try {
          pagingController.dispose();
        } catch (_) {}
      };
    }, [pagingController]);

    // 🔹 Date filter handler (fixed cancel bug)
    void _onDateRangeChanged(DateTimeRange? picked) {
      final already = dateRange.value;
      if (already == picked) return; // no change
      dateRange.value = picked;
      totalPages.value = null;
      try {
        pagingController.refresh();
      } catch (_) {}
    }

    // 🔹 Search handler
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

    // Selection logic
    void _toggleSelect(ProductDataModel product) {
      final id = product.productId;
      final ids = Set<int>.from(selectedIds.value);
      final map = Map<int, ProductDataModel>.from(selectedMap.value);
      if (ids.contains(id)) {
        ids.remove(id);
        map.remove(id);
      } else {
        ids.add(id);
        map[id] = product;
      }
      selectedIds.value = ids;
      selectedMap.value = map;
    }

    bool _isSelected(ProductDataModel p) =>
        selectedIds.value.contains(p.productId);

    // Quantity change handler (per item)
    void _onQuantityChanged(int productId, int value) {
      final qmap = Map<int, int>.from(quantities.value);
      if (value <= 0) {
        // optional: remove if zero
        qmap.remove(productId);
      } else {
        qmap[productId] = value;
      }
      quantities.value = qmap;
    }

    return FractionallySizedBox(
      heightFactor: 0.97,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // 🔹 Calendar Button (fixed cancel bug)
                          IconButton(
                            tooltip:
                                dateRange.value == null
                                    ? 'Filter by date'
                                    : 'Clear date filter',
                            icon:
                                dateRange.value == null
                                    ? const Icon(Icons.date_range)
                                    : const Icon(Icons.date_range_outlined),
                            onPressed: () async {
                              if (dateRange.value != null) {
                                _onDateRangeChanged(
                                  null,
                                ); // clear existing filter
                                return;
                              }
                              final dr = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (dr != null) {
                                _onDateRangeChanged(dr);
                              }
                              // If cancelled (dr == null), do nothing → list stays visible ✅
                            },
                          ),

                          IconButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pop<List<ProductDataModel>?>(null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    // 🔹 Search field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: TextField(
                        onChanged: onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search products',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              searchQuery.value.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => onSearchChanged(''),
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),

                    // 🔹 Product list (pagination)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: PagingListener<int, ProductDataModel>(
                          controller: pagingController,
                          builder: (context, state, fetchNextPage) {
                            if (state.isLoading &&
                                (state.pages?.isEmpty ?? true)) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (state.error != null &&
                                (state.pages?.isEmpty ?? true)) {
                              return Center(
                                child: ElevatedButton(
                                  onPressed: () => fetchNextPage(),
                                  child: const Text("Retry"),
                                ),
                              );
                            }

                            if (state.pages?.isEmpty ?? true) {
                              return const Center(
                                child: Text("No products found"),
                              );
                            }

                            return PagedListView<int, ProductDataModel>(
                              state: state,
                              fetchNextPage: fetchNextPage,
                              padding: const EdgeInsets.only(
                                bottom: 80,
                                left: 8,
                                right: 8,
                                top: 8,
                              ),
                              builderDelegate: PagedChildBuilderDelegate<
                                ProductDataModel
                              >(
                                itemBuilder: (context, product, index) {
                                  debugPrint(
                                    '${Constants.apiBaseUrl}${product.productImage}',
                                  );
                                  return Card(
                                    color: AppColors.cardColor,
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _toggleSelect(product),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: _isSelected(product),
                                              onChanged:
                                                  (_) => _toggleSelect(product),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    product.productName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF1B1140),
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    product.description,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 150,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFF7B8CFF,
                                                          ).withValues(
                                                            alpha: 0.12,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          product.sku,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black54,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8.0,
                                                        ),
                                                    child: Text(
                                                      _formatDate(
                                                        product.createdAt,
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 12),
                                                  SizedBox(
                                                    width: 150,
                                                    child: QuantityField(
                                                      initialValue: 1,
                                                      qytFillColor: Color(
                                                        0xFF7B8CFF,
                                                      ).withValues(alpha: 0.12),
                                                      onChanged: (value) {
                                                        _onQuantityChanged(
                                                          product.productId,
                                                          value,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 80,
                                                height: 80,
                                                color: const Color(
                                                  0xFF7B8CFF,
                                                ).withValues(alpha: 0.12),
                                                alignment: Alignment.center,
                                                child:
                                                    (product.productImage !=
                                                                null &&
                                                            product
                                                                .productImage!
                                                                .isNotEmpty)
                                                        ?
                                                        // Image.network(
                                                        //       '${Constants.apiBaseUrl}${product.productImage}',
                                                        //       width: 80,
                                                        //       height: 80,
                                                        //       fit: BoxFit.cover,
                                                        //       errorBuilder:
                                                        //           (_, __, ___) =>
                                                        //               const Icon(
                                                        //                 Icons.image,
                                                        //                 size: 36,
                                                        //               ),
                                                        //     )
                                                        SmartImage(
                                                          imageUrl:
                                                              product
                                                                  .productImage,
                                                          baseUrl:
                                                              Constants
                                                                  .apiBaseUrl,
                                                          height: 80,
                                                          width: 80,
                                                          fit: BoxFit.contain,
                                                          shape:
                                                              ImageShape
                                                                  .rectangle,
                                                          useCached: true,
                                                          errorWidget:
                                                              const Icon(
                                                                Icons.image,
                                                                size: 36,
                                                              ),
                                                          borderRadius: 4,
                                                          username:
                                                              product
                                                                  .productName,
                                                        )
                                                        : Text(
                                                          product
                                                                  .productName
                                                                  .isNotEmpty
                                                              ? product
                                                                  .productName[0]
                                                                  .toUpperCase()
                                                              : '—',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 28,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // 🔹 Save floating button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text('Save (${selectedIds.value.length})'),
                    onPressed: () {
                      final List<SelectedProducts> out = selectedMap
                          .value
                          .values
                          .map((p) {
                            final q = quantities.value[p.productId] ?? 1;
                            return SelectedProducts(product: p, quantity: q);
                          })
                          .toList(growable: false);

                      Navigator.of(context).pop<List<SelectedProducts>>(out);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PagedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PagedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedResponse.fromJson(
      Map<String, dynamic> j, T Function(Map<String, dynamic>) fromJsonT) {
    // ✅ backend sends "items", not "data"
    final inner = (j['items'] as List<dynamic>?) ?? <dynamic>[];

    return PagedResponse<T>(
      data: inner.map((e) => fromJsonT(Map<String, dynamic>.from(e))).toList(),
      total: _toInt(j['total']),
      page: _toInt(j['page']),
      pageSize: _toInt(j['pageSize']),
      totalPages: _toInt(j['totalPages']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

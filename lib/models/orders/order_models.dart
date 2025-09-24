// models/order_models.dart
import 'package:microsensors/models/orders/status_history_item.dart';

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

// String _toStr(dynamic v) {
//   if (v == null) return '';
//   return v.toString();
// }
//
// DateTime _toDate(dynamic v) {
//   if (v == null) return DateTime.now();
//   try {
//     return DateTime.parse(v.toString()).toLocal();
//   } catch (_) {
//     // fallback: try parsing numeric millis, else now
//     final numVal = int.tryParse(v.toString());
//     if (numVal != null) return DateTime.fromMillisecondsSinceEpoch(numVal).toLocal();
//     return DateTime.now();
//   }
// }

class OrderListItem {
  final int orderId;
  final int productId;
  final String productName;
  final String productImage; // may be empty string if API didn't provide it
  final String sku;
  final int productionManagerId;
  final String productionManagerName;
  final String? productionManagerImage;
  final int quantity;
  final String currentStatus;
  final DateTime createdAt;
  final List<StatusHistoryItem>? statusHistory;


  OrderListItem({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.sku,
    required this.productionManagerId,
    required this.productionManagerName,
    required this.productionManagerImage,
    required this.quantity,
    required this.currentStatus,
    required this.createdAt,
    required this.statusHistory,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> j) {
    return OrderListItem(
      orderId: j['orderId'] as int,
      productId: j['productId'] as int,
      productName: j['productName'] as String,
      productImage: (j['productImage'] ?? '') as String,
      sku: (j['sku'] ?? '') as String,
      productionManagerId: j['productionManagerId'] as int? ?? 0,
      productionManagerName: (j['productionManagerName'] ?? '') as String,
      productionManagerImage: (j['productionManagerImage'] ?? '') as String,
      quantity: (j['quantity'] ?? 0) as int,
      currentStatus: (j['currentStatus'] ?? '') as String,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      statusHistory: (j['statusHistory'] as List<dynamic>?)
          ?.map((e) => StatusHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          <StatusHistoryItem>[],
    );
  }
}

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
    final inner = (j['data'] as List<dynamic>?) ?? <dynamic>[];
    return PagedResponse<T>(
      data: inner.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      total: _toInt(j['total']),
      page: _toInt(j['page']),
      pageSize: _toInt(j['pageSize']),
      totalPages: _toInt(j['totalPages']),
    );
  }
}

// Drop-in replacement for _buildOrderCard
import 'package:flutter/material.dart';

import '../../../models/orders/order_models.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';
import 'order_details_bottomsheet.dart';

Widget orderCardWidget(BuildContext context, OrderListItem orderItem) {
  void openDetailsSheet(BuildContext context) async {
    // ignore: unused_local_variable
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
                bottom: true, // protect from home indicator / gesture area
                // keep top as part of the sheet (AppBar handles status)
                child: Scaffold(
                  appBar: AppBar(
                    elevation: 0,
                    backgroundColor: Colors.white,
                    iconTheme: const IconThemeData(color: Colors.black),
                    title: Text(
                      orderItem.productName,
                      style: const TextStyle(color: Colors.black),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  body: OrderDetailsBottomsheet(orderItem: orderItem),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return Card(
    elevation: 4,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(25), // <-- Card radius
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          openDetailsSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left thin accent bar
              Container(
                width: 6,
                height: 180,
                decoration: BoxDecoration(
                  color: _statusColor(
                    orderItem.currentStatus,
                  ).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),

              Column(
                children: [
                  SmartImage(
                    imageUrl: orderItem.productImage,
                    baseUrl: Constants.apiBaseUrl,
                    username: orderItem.productName,
                    shape: ImageShape.rectangle,
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 12),
                  // status chip
                  _buildStatusChip(orderItem.currentStatus),
                ],
              ),

              SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title + time
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: orderItem.productName,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: ' | ',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                TextSpan(
                                  text: '#${orderItem.orderId}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _timeAgo(orderItem.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 6),

                    // subtitle lines
                    Text(
                      'SKU: ${orderItem.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qty: ${orderItem.quantity}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                "Assigned to: ${orderItem.productionManagerName}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// small status chip with icon
Widget _buildStatusChip(String status) {
  final color = _statusColor(status);
  final icon = _statusIcon(status);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// pick a color for status
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'created':
      return Colors.green;
    case 'in production':
    case 'production':
      return Colors.blue;
    case 'shipped':
      return Colors.deepPurple;
    case 'delivered':
      return Colors.indigo;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey.shade700;
  }
}

// pick an icon for status
IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'created':
      return Icons.add_box;
    case 'in production':
    case 'production':
      return Icons.construction;
    case 'shipped':
      return Icons.local_shipping;
    case 'delivered':
      return Icons.check_circle;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.info;
  }
}

// small helper that returns relative time like "2h" or "3d"
String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 4) return '${weeks}w';
  return '${dt.day}/${dt.month}/${dt.year}';
}

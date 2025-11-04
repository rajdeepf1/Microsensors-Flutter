// Drop-in replacement for _buildOrderCard
import 'package:flutter/material.dart';

import '../../../models/orders/order_response_model.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';
import 'sales_order_details_bottomsheet.dart';

Widget orderCardWidget(BuildContext context, OrderResponseModel item) {
  final accent = Constants.statusColor(item.status);

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
                      item.clientName!,
                      style: const TextStyle(color: Colors.black),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  body: SalesOrderDetailsBottomsheet(orderItem: item),
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openDetailsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 180,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            SmartImage(
                              imageUrl: '',
                              baseUrl: Constants.apiBaseUrl,
                              username: item.clientName,
                              shape: ImageShape.rectangle,
                              height: 120,
                              width: 120,
                              useCached: true,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: item.clientName ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const WidgetSpan(
                                            child: SizedBox(width: 8),
                                          ),
                                          TextSpan(
                                            text: '| ',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' #${item.orderId}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Order Dt.:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          SizedBox(width: 2,),
                                          Text(
                                            Constants.timeAgo(item.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 5,),
                                      if (item.dispatchOn!=null) Row(
                                        children: [
                                          Text(
                                            'Dispatch Dt.:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          SizedBox(width: 2,),
                                          Text(
                                            Constants.timeAgo(item.dispatchOn),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      )


                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Remarks: ${item?.remarks ?? "-"}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total No. Products: ${item.items.length ?? 0}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Assigned by: ${item.salesPersonName ?? "Unassigned"}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Assigned to: ${item.productionManagerName ?? "Unassigned"}',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusChip(item.status ?? ''),
                        const SizedBox(width: 12),
                        _buildStatusChip(item.priority ?? ''),
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
  final color = Constants.statusColor(status);
  final icon = Constants.statusIcon(status);
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

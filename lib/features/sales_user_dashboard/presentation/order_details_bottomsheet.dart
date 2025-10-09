import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/utils/constants.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../../../models/orders/order_models.dart';

class OrderDetailsBottomsheet extends HookWidget {
  final OrderListItem orderItem;

  const OrderDetailsBottomsheet({super.key, required this.orderItem});

  @override
  Widget build(BuildContext context) {
    final cardColor = _statusColor(orderItem.currentStatus).withValues(alpha: 0.12);

    // canonical steps (same as timeline widget)
    final steps = <String>[
      'Created',
      'Received',
      'Production Started',
      'Production Completed',
      'Dispatched',
      'Acknowledged',
    ];

    // increase per-step height to make timeline more spacious
    final double timelineHeight = (steps.length * 120).clamp(220.0, 1200.0).toDouble();

    final Map<String, DateTime?> stepTimes = Map.fromEntries(
      (orderItem.statusHistory ?? [])
          .where((h) => (h.newStatus ?? '').isNotEmpty)
          .map((h) => MapEntry(h.newStatus!, h.changedAt)),
    );


    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- ticket-style card ---
            ClipPath(
              clipper: ZigZagTicketClipper(
                toothWidth: 12,
                toothHeight: 12,
                borderRadius: 12,
              ),
              child: Container(
                color: cardColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // product image (full width)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 200,
                            child: SmartImage(
                              imageUrl: orderItem.productImage,
                              baseUrl: Constants.apiBaseUrl,
                              height: 200,
                              shape: ImageShape.rectangle,
                              username: orderItem.productName,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // content area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header: order number + status chip + time
                          Row(
                            children: [
                              Text(
                                'Order ID: #${orderItem.orderId}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: _buildStatusChip(orderItem.currentStatus),
                                ),
                              ),
                              Text(
                                Constants.timeAgo(orderItem.createdAt),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text('Assigned to', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),

                          const SizedBox(height: 12),

                          // product row: thumbnail, name + sku, qty
                          Row(
                            children: [
                              // if (orderItem.productionManagerImage != null &&
                              //     orderItem.productionManagerImage!.isNotEmpty)
                                SmartImage(
                                  imageUrl: orderItem.productionManagerImage,
                                  baseUrl: Constants.apiBaseUrl,
                                  height: 48,
                                  width: 48,
                                  shape: ImageShape.circle,
                                  username: orderItem.productionManagerName,
                                  fit: BoxFit.cover,
                                ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (orderItem.productionManagerName.isNotEmpty)
                                          ? orderItem.productionManagerName
                                          : 'Unassigned',
                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Manager', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Qty ${orderItem.quantity}', style: TextStyle(fontSize: 13)),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(orderItem.productName, style: const TextStyle(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text('SKU: ${orderItem.sku}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // bottom spacing to expose zig-zag nicely
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // make the gap below zigzag larger so the timeline doesn't overlap
            const SizedBox(height: 20),

            const Text("Timeline", style: TextStyle(fontSize: 18)),

            // big left/top padding to guarantee first connector is visible
            Padding(
              padding: const EdgeInsets.only(left: 18.0, right: 12.0, /*top: 16.0*/),
              child: SizedBox(
                height: timelineHeight, // you already computed above
                child: AbsorbPointer(
                  absorbing: true, // timeline won't receive pointer events
                  child: buildStatusTimelineVerticalWithHook(
                    orderItem.currentStatus,
                    stepTimes: stepTimes,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// small status chip with icon
Widget _buildStatusChip(String status) {
  final color = _statusColor(status);
  final icon = _statusIcon(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// pick a color for status
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'created':
      return Colors.green;
    case 'received':
      return Colors.lightGreen;
    case 'in production':
    case 'production':
      return Colors.blue;
    case 'production completed':
      return Colors.teal;
    case 'dispatched':
    case 'shipped':
      return Colors.deepPurple;
    case 'acknowledged':
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
    case 'received':
      return Icons.download_rounded;
    case 'in production':
    case 'production':
      return Icons.construction;
    case 'production completed':
      return Icons.done_all;
    case 'dispatched':
    case 'shipped':
      return Icons.local_shipping;
    case 'acknowledged':
      return Icons.check_circle;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.info;
  }
}

/// ZigZagTicketClipper unchanged
class ZigZagTicketClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;
  final double borderRadius;

  ZigZagTicketClipper({this.toothWidth = 12.0, this.toothHeight = 12.0, this.borderRadius = 12.0});

  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, borderRadius);
    path.lineTo(size.width, size.height - toothHeight - borderRadius);
    path.quadraticBezierTo(size.width, size.height - toothHeight, size.width - borderRadius, size.height - toothHeight);

    double x = size.width - borderRadius;
    final double leftLimit = borderRadius;
    final availableWidth = x - leftLimit;
    int count = (availableWidth / toothWidth).floor();
    if (count <= 0) count = 1;
    final adjustedToothWidth = availableWidth / count;

    path.lineTo(x, size.height - toothHeight);
    for (int i = 0; i < count; i++) {
      final nextX = x - adjustedToothWidth;
      final midX = (x + nextX) / 2;
      path.lineTo(midX, size.height);
      path.lineTo(nextX, size.height - toothHeight);
      x = nextX;
    }

    path.lineTo(leftLimit, size.height - toothHeight);
    path.quadraticBezierTo(0, size.height - toothHeight, 0, size.height - toothHeight - borderRadius);
    path.lineTo(0, borderRadius);
    path.quadraticBezierTo(0, 0, borderRadius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ZigZagTicketClipper oldClipper) {
    return oldClipper.toothWidth != toothWidth || oldClipper.toothHeight != toothHeight || oldClipper.borderRadius != borderRadius;
  }
}

/// Hook-based animated indicator.
/// Shows a continuously pulsing ripple behind a solid center dot when isActive==true.
/// Uses flutter_hooks for controller lifecycle.
class AnimatedIndicatorHook extends HookWidget {
  final bool isActive;
  final double size;
  final Color color;
  final Color innerColor;

  const AnimatedIndicatorHook({
    super.key,
    required this.isActive,
    this.size = 22.0,
    required this.color,
    Color? innerColor,
  }) : innerColor = innerColor ?? Colors.white;

  @override
  Widget build(BuildContext context) {
    // controller lifecycle handled by hook
    final ctrl = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );

    // Start/stop based on isActive
    useEffect(() {
      if (isActive) {
        ctrl.repeat();
      } else {
        ctrl.stop(canceled: false);
        ctrl.value = 0.0; // reset to start
      }
      return null;
    }, [isActive]);

    // ensure widget rebuilds when controller ticks
    useListenable(ctrl);

    // create eased value 0..1
    final double eased = Curves.easeOut.transform(ctrl.value.clamp(0.0, 1.0));

    // derived scale & opacity
    final double minScale = 0.6;
    final double maxScale = 1.8;
    final double scale = isActive ? (minScale + (maxScale - minScale) * eased) : 0.0;
    final double rippleOpacity = isActive ? (0.45 * (1.0 - eased)) : 0.0;

    // outer box to give space for ripple
    final double outerSize = size * 2.0;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ripple
          if (isActive)
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: rippleOpacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

          // Center dot with subtle border and inner dot
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2)),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
            ),
            alignment: Alignment.center,
            child: Container(
              width: size * 0.45,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: innerColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example timeline builder that uses the hook-based animated indicator.
Widget buildStatusTimelineVerticalWithHook(String currentStatus, {Map<String, DateTime?>? stepTimes}) {
  final steps = <String>[
    'Created',
    'Received',
    'Production Started',
    'Production Completed',
    'Dispatched',
    'Acknowledged',
  ];

  int activeIndex = steps.indexWhere((s) => s.toLowerCase() == currentStatus.toLowerCase());
  if (activeIndex < 0) activeIndex = 0;

  const double indicatorSize = 18.0;
  const double connectorThickness = 4.0;
  final Color activeColor = Colors.blue;
  final Color doneColor = Colors.green;
  final Color pendingColor = Colors.grey.shade400;

  return Padding(
    padding: const EdgeInsets.only(left: 16.0, /*top: 12.0,*/ right: 8.0),
    child: Timeline.tileBuilder(
      theme: TimelineThemeData(
        direction: Axis.vertical,
        nodePosition: 0.12,
        connectorTheme: ConnectorThemeData(thickness: connectorThickness, space: 36),
      ),
      builder: TimelineTileBuilder.connected(
        itemCount: steps.length,
        indicatorBuilder: (context, index) {
          final bool done = index < activeIndex;
          final bool active = index == activeIndex;

          if (done) {
            return DotIndicator(
              size: indicatorSize,
              color: doneColor,
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            );
          } else if (active) {
            return AnimatedIndicatorHook(
              isActive: true,
              size: indicatorSize,
              color: activeColor,
            );
          } else {
            return DotIndicator(size: indicatorSize, color: pendingColor);
          }
        },
        connectorBuilder: (context, index, type) {
          final bool isDone = index < activeIndex;
          return SolidLineConnector(
            color: isDone ? doneColor : pendingColor,
            thickness: connectorThickness,
          );
        },
        contentsBuilder: (context, index) {
          final label = steps[index];
          final DateTime? ts = stepTimes?[label];

          String tsText = '';
          if (ts != null) {
            final dt = ts.toLocal();
            tsText =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }

          final double extraTop = index == 0 ? 12.0 : 0.0;

          return Padding(
            padding: EdgeInsets.only(left: 14.0, bottom: 38.0, top: 38.0 + extraTop, right: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: index == activeIndex ? FontWeight.w700 : FontWeight.w600,
                    color: index == activeIndex ? activeColor : Colors.black87,
                  ),
                ),
                if (tsText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(tsText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

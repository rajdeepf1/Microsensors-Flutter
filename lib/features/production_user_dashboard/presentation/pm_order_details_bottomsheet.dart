// lib/features/production_user_dashboard/presentation/pm_order_details_bottomsheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/smart_image/smart_image.dart';
import 'package:microsensors/models/orders/production_manager_change_status_response.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../../../models/orders/production_manager_order_list.dart';
import '../../components/user/user_info_edit_field.dart';

// new imports
import '../../../core/local_storage_service.dart';
import '../../../core/api_state.dart';
import '../repository/production_manager_repo.dart';

/// Bottom sheet showing order details + timeline for PM
class PmOrderDetailsBottomsheet extends HookWidget {
  final PmOrderListItem orderItem;
  final bool isHistorySearchScreen;

  const PmOrderDetailsBottomsheet({
    super.key,
    required this.orderItem,
    required this.isHistorySearchScreen,
  });

  @override
  Widget build(BuildContext context) {
    // repo instance
    final repo = useMemoized(() => ProductionManagerRepository());

    final Color baseColor = _statusColor(orderItem.currentStatus);
    final Color cardColor = baseColor.withValues(alpha: 0.12);

    // status backed by hook (defaults to order's current status)
    final status = useState<String?>(orderItem.currentStatus ?? 'Created');

    // canonical steps (same as timeline widget)
    final steps = <String>[
      'Created',
      'Received',
      'Production Started',
      'Production Completed',
      'Dispatched',
      'Acknowledged',
    ];

    final List<DropdownMenuItem<String>> statusItems =
        steps
            .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
            .toList();

    // compute timeline height (spacious)
    final double timelineHeight =
        (steps.length * 120).clamp(220.0, 1200.0).toDouble();

    // build initial stepTimes map from existing history (defensive parsing)
    Map<String, DateTime?> buildInitialStepTimes() {
      final Map<String, DateTime?> m = {};
      // ignore: unnecessary_null_comparison
      if (orderItem.statusHistory != null) {
        for (final h in orderItem.statusHistory) {
          final key = (h.newStatus ?? '').trim();
          if (key.isNotEmpty) {
            DateTime? ts;

            // Defensive parsing: handle DateTime, String, or other
            final dynamic ch = h.changedAt;
            if (ch is DateTime) {
              ts = ch;
            } else if (ch is String && ch.isNotEmpty) {
              // ch is a runtime String — safe to pass to tryParse
              ts = DateTime.tryParse(ch);
            } else if (ch != null) {
              // fallback: attempt to parse string representation
              try {
                ts = DateTime.parse(ch.toString());
              } catch (_) {
                ts = null;
              }
            } else {
              ts = null;
            }

            m[key] = ts;
          }
        }
      }
      // ensure that the order's current status at least has an entry (if created but no history timestamp)
      if ((orderItem.currentStatus ?? '').isNotEmpty &&
          m[orderItem.currentStatus!] == null) {
        m[orderItem.currentStatus!] = orderItem.createdAt;
      }
      return m;
    }

    final stepTimesState = useState<Map<String, DateTime?>>(
      buildInitialStepTimes(),
    );

    // when user selects a status from dropdown: update status and set timestamp now + call backend
    Future<void> onStatusSelected(String? newStatus) async {
      if (newStatus == null) return;
      if (newStatus == status.value) return;

      // --- BEGIN: guard against disallowed transitions ---
      final allowedList = orderItem.allowedNextStatuses;
      final bool allowedMatch = allowedList.any(
        (s) =>
            // ignore: unnecessary_null_comparison
            s != null &&
            s.trim().toLowerCase() == newStatus.trim().toLowerCase(),
      );

      if (!allowedMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot change status to "$newStatus". Allowed next status${allowedList.length == 1 ? '' : 'es'}: '
              '${allowedList.isEmpty ? 'None' : allowedList.join(", ")}',
            ),
          ),
        );
        return; // abort — do not call API
      }
      // --- END guard ---

      final prevStatus = status.value;
      final prevStepTimes = Map<String, DateTime?>.from(stepTimesState.value);

      // optimistic UI update
      status.value = newStatus;
      final now = DateTime.now();
      final next = Map<String, DateTime?>.from(stepTimesState.value);
      next[newStatus] = now;
      stepTimesState.value = next;

      // loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // get changedBy from local user (fallback to productionManagerId in orderItem)
        int changedBy = orderItem.productionManagerId ?? -1;
        final stored = await LocalStorageService().getUser();
        // ignore: unnecessary_null_comparison
        if (stored != null && stored.userId != null) changedBy = stored.userId;

        final ApiState<ProductionManagerChangeStatusResponse> res = await repo
            .changeOrderStatus(
              orderId: orderItem.orderId ?? -1,
              newStatus: newStatus,
              changedBy: changedBy,
            );

        // hide loader
        if (Navigator.canPop(context)) Navigator.of(context).pop();

        if (res is ApiData<ProductionManagerChangeStatusResponse>) {
          final updated = res.data;
          // Update UI with authoritative server data:
          // - status
          if (updated.status != null) status.value = updated.status;

          // - update stepTimesState with server updatedAt for the current status (best-effort)
          // server returned updatedAt field; attach it to step times for the selected status
          if (updated.updatedAt != null) {
            final next2 = Map<String, DateTime?>.from(stepTimesState.value);
            next2[status.value!] = updated.updatedAt;
            stepTimesState.value = next2;
          }

          // success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to "${status.value}"')),
          );

          Navigator.of(context).pop(true);
        } else if (res is ApiError<ProductionManagerChangeStatusResponse>) {
          // revert optimistic UI
          status.value = prevStatus;
          stepTimesState.value = prevStepTimes;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change status: ${res.message}')),
          );
        } else {
          status.value = prevStatus;
          stepTimesState.value = prevStepTimes;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to change status')),
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        status.value = prevStatus;
        stepTimesState.value = prevStepTimes;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
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
                              username: orderItem.productName ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // content area
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header: order number + status chip + time
                          Row(
                            children: [
                              Text(
                                'Order ID: #${orderItem.orderId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: _buildStatusChip(
                                    status.value ??
                                        orderItem.currentStatus ??
                                        '',
                                  ),
                                ),
                              ),
                              Text(
                                Constants.timeAgo(orderItem.createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // product row: thumbnail, name + sku, qty
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderItem.productName ?? '',
                                      style: const TextStyle(fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'SKU: ${orderItem.sku ?? '-'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Qty ${orderItem.quantity ?? 0}',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Sales person column
                              Row(
                                children: [
                                  SmartImage(
                                    imageUrl: orderItem.salesPersonImage,
                                    baseUrl: Constants.apiBaseUrl,
                                    height: 48,
                                    width: 48,
                                    shape: ImageShape.circle,
                                    username: orderItem.salesPersonName ?? '',
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (orderItem.salesPersonName ?? '')
                                                .isNotEmpty
                                            ? orderItem.salesPersonName!
                                            : 'Unassigned',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sales',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // small arrow
                              Icon(
                                Icons.arrow_forward,
                                color: AppColors.appBlueColor,
                                size: 18,
                              ),

                              const Spacer(),

                              // Production manager column
                              Row(
                                children: [
                                  SmartImage(
                                    imageUrl: orderItem.productionManagerImage,
                                    baseUrl: Constants.apiBaseUrl,
                                    height: 48,
                                    width: 48,
                                    shape: ImageShape.circle,
                                    username:
                                        orderItem.productionManagerName ?? '',
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (orderItem.productionManagerName ?? '')
                                                .isNotEmpty
                                            ? orderItem.productionManagerName!
                                            : 'Unassigned',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Prod. Manager',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

            //here
            !isHistorySearchScreen
                ?
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                    children: [
                      const SizedBox(height: 18),
                      // Status dropdown -> updates timeline when changed
                      UserInfoEditField(
                        text: "Status",
                        child: DropdownButtonFormField<String>(
                          initialValue: status.value,
                          items: statusItems,
                          icon: const Icon(Icons.expand_more),
                          onChanged:
                              (value) async => await onStatusSelected(value),
                          style: TextStyle(
                            color: AppColors.subHeadingTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Select Status',
                            filled: true,
                            fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 16.0,
                            ),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(Radius.circular(50)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
            )
                : SizedBox.shrink(),

            const SizedBox(height: 20),

            const Text("Timeline", style: TextStyle(fontSize: 18)),

            // timeline area (reacts to status.value and stepTimesState.value)
            Padding(
              padding: const EdgeInsets.only(
                left: 18.0,
                right: 12.0,
                //top: 16.0,
              ),
              child: SizedBox(
                height: timelineHeight,
                child: AbsorbPointer(
                  absorbing: true,
                  child: buildStatusTimelineVerticalWithHook(
                    status.value ?? orderItem.currentStatus ?? '',
                    stepTimes: stepTimesState.value,
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
Widget _buildStatusChip(String? status) {
  final s = status ?? '';
  final color = _statusColor(s);
  final icon = _statusIcon(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          s,
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
Color _statusColor(String? status) {
  final s = (status ?? '').toLowerCase();
  switch (s) {
    case 'created':
      return Colors.green;
    case 'received':
      return Colors.lightGreen;
    case 'production started':
      return Colors.blue;
    case 'production completed':
      return Colors.teal;
    case 'dispatched':
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
IconData _statusIcon(String? status) {
  final s = (status ?? '').toLowerCase();
  switch (s) {
    case 'created':
      return Icons.add_box;
    case 'received':
      return Icons.download_rounded;
    case 'production started':
      return Icons.construction;
    case 'production completed':
      return Icons.done_all;
    case 'dispatched':
      return Icons.local_shipping;
    case 'acknowledged':
      return Icons.check_circle;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.info;
  }
}

/// ZigZagTicketClipper (unchanged logic but fixed types)
class ZigZagTicketClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;
  final double borderRadius;

  ZigZagTicketClipper({
    this.toothWidth = 12.0,
    this.toothHeight = 12.0,
    this.borderRadius = 12.0,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, borderRadius);
    path.lineTo(size.width, size.height - toothHeight - borderRadius);
    path.quadraticBezierTo(
      size.width,
      size.height - toothHeight,
      size.width - borderRadius,
      size.height - toothHeight,
    );

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
    path.quadraticBezierTo(
      0,
      size.height - toothHeight,
      0,
      size.height - toothHeight - borderRadius,
    );
    path.lineTo(0, borderRadius);
    path.quadraticBezierTo(0, 0, borderRadius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ZigZagTicketClipper oldClipper) {
    return oldClipper.toothWidth != toothWidth ||
        oldClipper.toothHeight != toothHeight ||
        oldClipper.borderRadius != borderRadius;
  }
}

/// AnimatedIndicatorHook — pulsing ripple when active
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
    final ctrl = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      if (isActive) {
        ctrl.repeat();
      } else {
        ctrl.stop(canceled: false);
        ctrl.value = 0.0;
      }
      return null;
    }, [isActive]);

    useListenable(ctrl);

    final double eased = Curves.easeOut.transform(ctrl.value.clamp(0.0, 1.0));
    final double minScale = 0.6;
    final double maxScale = 1.8;
    final double scale =
        isActive ? (minScale + (maxScale - minScale) * eased) : 0.0;
    final double rippleOpacity = isActive ? (0.45 * (1.0 - eased)) : 0.0;
    final double outerSize = size * 2.0;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 2,
              ),
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

/// Timeline builder that uses timelines_plus; hook-friendly indicators are used
Widget buildStatusTimelineVerticalWithHook(
  String currentStatus, {
  Map<String, DateTime?>? stepTimes,
}) {
  final steps = <String>[
    'Created',
    'Received',
    'Production Started',
    'Production Completed',
    'Dispatched',
    'Acknowledged',
  ];

  int activeIndex = steps.indexWhere(
    (s) => s.toLowerCase() == (currentStatus).toLowerCase(),
  );
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
        connectorTheme: const ConnectorThemeData(
          thickness: connectorThickness,
          space: 36,
        ),
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
            padding: EdgeInsets.only(
              left: 14.0,
              bottom: 38.0,
              top: 38.0 + extraTop,
              right: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        index == activeIndex
                            ? FontWeight.w700
                            : FontWeight.w600,
                    color: index == activeIndex ? activeColor : Colors.black87,
                  ),
                ),
                if (tsText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      tsText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

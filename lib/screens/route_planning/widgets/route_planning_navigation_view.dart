import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme_extensions.dart';
import '../../../services/osm_router_service.dart';
import '../route_planning_page.dart';
import 'route_planning_widgets.dart';

class RoutePlanningNavigationView extends StatelessWidget {
  final RoutePlanningPageContentState state;

  const RoutePlanningNavigationView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final double pivotLat =
        state.completedQueue.isNotEmpty && state.completedQueue.last.latitude != null
        ? state.completedQueue.last.latitude!
        : state.currentLat;
    final double pivotLng =
        state.completedQueue.isNotEmpty && state.completedQueue.last.longitude != null
        ? state.completedQueue.last.longitude!
        : state.currentLng;

    if (state.remainingQueue.isEmpty) {
      return state.buildCompletionCard();
    }

    final activeCustomer = state.remainingQueue.first;
    double activeDistance = 0.0;
    if (activeCustomer.latitude != null && activeCustomer.longitude != null) {
      final segment = OsmRouterService().findRoute(
        LatLng(pivotLat, pivotLng),
        LatLng(activeCustomer.latitude!, activeCustomer.longitude!),
      );
      activeDistance = OsmRouterService().calculateRouteDistance(segment);
    }

    final totalRemaining = state.remainingQueue.length;
    final totalCompleted = state.completedQueue.length;
    final totalPlanned = totalRemaining + totalCompleted;
    final progress = totalPlanned > 0 ? totalCompleted / totalPlanned : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox.expand(
      child: Stack(
        children: [
          // 1. Full Screen Live Map (Background)
          Positioned.fill(
            child: ClipRRect(
              child: state.buildEmbeddedMap(),
            ),
          ),

          // 2. Float Controls Column (Top Right) - Follow GPS & Fit Screen FABs
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'followGpsNav',
                  onPressed: () => state.isFollowingGps = !state.isFollowingGps,
                  tooltip: state.isFollowingGps
                      ? 'ปิดการติดตาม GPS'
                      : 'เปิดการติดตาม GPS',
                  backgroundColor: state.isFollowingGps
                      ? const Color(0xFF2196F3)
                      : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                  foregroundColor: state.isFollowingGps
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  child: Icon(
                    state.isFollowingGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fitRouteNav',
                  onPressed: state.fitMapToRoute,
                  tooltip: 'แสดงเส้นทางทั้งหมด',
                  backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  child: const Icon(Icons.fit_screen),
                ),
              ],
            ),
          ),

          // 3. Draggable Scrollable Bottom Sheet containing active customer info & queue
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.35, 0.85],
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE0F2F1),
                      width: 1.0,
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Header Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'คิวเส้นทางจัดส่ง',
                                style: kanitTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'จุดหมายที่ $totalCompleted / $totalPlanned',
                                style: kanitTextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00897B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar
                          LinearProgressIndicator(
                            value: progress,
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 8,
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF5F5F5),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00897B),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Active Customer Card
                          Card(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: const Color(0xFF00897B).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00897B),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'จุดหมายปัจจุบัน (Active)',
                                          style: kanitTextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'ห่าง ~${activeDistance.toStringAsFixed(2)} กม.',
                                        style: kanitTextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF00897B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    activeCustomer.name,
                                    style: kanitTextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 14,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'เบอร์โทร: ${activeCustomer.phone}',
                                        style: kanitTextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'ที่อยู่: ${activeCustomer.address}',
                                          style: kanitTextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              state.showNavigationOptions(activeCustomer),
                                          icon: const Icon(Icons.navigation_outlined),
                                          label: const Text('นำทาง'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF00897B),
                                            side: const BorderSide(
                                              color: Color(0xFF00897B),
                                              width: 1.5,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          key: const Key('jobCompletedButton'),
                                          onPressed: state.completeActiveDestination,
                                          icon: const Icon(Icons.check_circle_outline),
                                          label: const Text('งานเสร็จสิ้น'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF00897B),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Routing Mode Selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'คิวที่เหลือ (${totalRemaining - 1} จุดหมาย)',
                                  style: kanitTextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: SegmentedButton<bool>(
                                  segments: const <ButtonSegment<bool>>[
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text('จัดอัตโนมัติ'),
                                      icon: Icon(Icons.check, size: 16),
                                    ),
                                    ButtonSegment<bool>(
                                      value: false,
                                      label: Text('จัดเอง'),
                                    ),
                                  ],
                                  selected: <bool>{state.isAutoMode},
                                  onSelectionChanged: (Set<bool> newSelection) {
                                    state.toggleRouteMode(newSelection.first);
                                  },
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return const Color(0xFF00897B);
                                          }
                                          return isDark
                                              ? const Color(0xFF2C2C2C)
                                              : const Color(0xFFF5F5F5);
                                        }),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return Colors.white;
                                          }
                                          return isDark ? Colors.white70 : Colors.black87;
                                        }),
                                    side: WidgetStateProperty.all(BorderSide.none),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Reorderable / auto queue list
                          state.isAutoMode
                              ? ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: state.remainingQueue.length - 1,
                                  itemBuilder: (context, idx) {
                                    final itemIdx = idx + 1;
                                    final customer = state.remainingQueue[itemIdx];
                                    final double prevLat =
                                        state.remainingQueue[idx].latitude!;
                                    final double prevLng =
                                        state.remainingQueue[idx].longitude!;
                                    final segment = OsmRouterService().findRoute(
                                      LatLng(prevLat, prevLng),
                                      LatLng(customer.latitude!, customer.longitude!),
                                    );
                                    final double distance = OsmRouterService()
                                        .calculateRouteDistance(segment);
                                    return QueueItemCard(
                                      index: itemIdx + totalCompleted,
                                      name: customer.name,
                                      address: customer.address,
                                      phone: customer.phone,
                                      distanceLabel:
                                          'ระยะห่างจากจุดก่อนหน้า ~${distance.toStringAsFixed(2)} กม.',
                                      trailing: Icon(
                                        Icons.lock_clock,
                                        color: Colors.grey.shade400,
                                      ),
                                    );
                                  },
                                )
                              : ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: state.remainingQueue.length - 1,
                                  onReorder: (oldIndex, newIndex) {
                                    state.reorderQueue(oldIndex, newIndex);
                                  },
                                  itemBuilder: (context, idx) {
                                    final itemIdx = idx + 1;
                                    final customer = state.remainingQueue[itemIdx];
                                    final double prevLat =
                                        state.remainingQueue[idx].latitude!;
                                    final double prevLng =
                                        state.remainingQueue[idx].longitude!;
                                    final segment = OsmRouterService().findRoute(
                                      LatLng(prevLat, prevLng),
                                      LatLng(customer.latitude!, customer.longitude!),
                                    );
                                    final double distance = OsmRouterService()
                                        .calculateRouteDistance(segment);
                                    return QueueItemCard(
                                      key: ValueKey(customer.phone),
                                      index: itemIdx + totalCompleted,
                                      name: customer.name,
                                      address: customer.address,
                                      phone: customer.phone,
                                      distanceLabel:
                                          'ระยะห่าง ~${distance.toStringAsFixed(2)} กม.',
                                      trailing: const Icon(Icons.drag_handle),
                                    );
                                  },
                                ),
                          const SizedBox(height: 8),

                          // Cancel Navigation Button
                          TextButton.icon(
                            onPressed: state.resetNavigation,
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            label: Text(
                              'ยกเลิกแผนการเดินทาง',
                              style: kanitTextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

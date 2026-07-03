import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme_extensions.dart';
import '../../../services/osm_router_service.dart';
import '../../../models/customer_record.dart';
import '../route_planning_page.dart';
import 'route_planning_widgets.dart';

/// หน้าจอนำทางขณะขับรถขนส่งจริง (Active Navigation Mode View) ตกแต่งสไตล์แผนที่นำทาง GPS (Google Maps)
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

          // 2. Turn-by-Turn GPS HUD Card (Top Center-Left)
          Positioned(
            top: 16,
            left: 16,
            right: 80, // Leave room for floating action buttons on the right
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                      : [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'จุดหมายปัจจุบัน (Active)',
                          style: kanitTextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'มุ่งสู่: ${activeCustomer.name}',
                          style: kanitTextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          activeCustomer.address,
                          style: kanitTextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Float Controls Column (Top Right)
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
                      ? const Color(0xFF33BCB4)
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

          // 4. Floating Navigation HUD Dashboard (Bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE0F5F4),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'คิวเส้นทางจัดส่ง',
                    style: kanitTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Distance & Progress HUD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'อีก ~${activeDistance.toStringAsFixed(1)} กม.',
                            style: kanitTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF33BCB4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'จุดหมายที่ $totalCompleted / $totalPlanned',
                            style: kanitTextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Progress Bar
                      SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(progress * 100).round()}%',
                              style: kanitTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF33BCB4),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : const Color(0xFFF5F5F5),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF33BCB4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 10),
                  // HUD Quick Actions
                  Row(
                    children: [
                      // Job Completion Button (Success)
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('jobCompletedButton'),
                          onPressed: state.completeActiveDestination,
                          icon: const Icon(Icons.check, color: Colors.white, size: 16),
                          label: Text(
                            'ส่งสำเร็จ',
                            style: kanitTextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32), // Green Google-Maps Style
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Phone Link Button
                      IconButton(
                        onPressed: () => state.callCustomer(activeCustomer.phone),
                        icon: const Icon(Icons.phone, color: Color(0xFF33BCB4), size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF33BCB4).withOpacity(0.08),
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Google Maps Link Button
                      IconButton(
                        onPressed: () => state.showNavigationOptions(activeCustomer),
                        icon: const Icon(Icons.navigation, color: Color(0xFF33BCB4), size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF33BCB4).withOpacity(0.08),
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Queue View trigger button
                      IconButton(
                        onPressed: () => _showQueueBottomSheet(context, isDark),
                        icon: const Icon(Icons.format_list_bulleted, color: Color(0xFF33BCB4), size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF33BCB4).withOpacity(0.08),
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, bool isDark) {
    final totalRemaining = state.remainingQueue.length;
    final totalCompleted = state.completedQueue.length;
    final totalPlanned = totalRemaining + totalCompleted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ลำดับคิวการส่งของ',
                        style: kanitTextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Segmented button
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
                              icon: Icon(Icons.check, size: 14),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('จัดเอง'),
                            ),
                          ],
                          selected: <bool>{state.isAutoMode},
                          onSelectionChanged: (Set<bool> newSelection) {
                            state.toggleRouteMode(newSelection.first);
                            setModalState(() {});
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF33BCB4);
                              }
                              return isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
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
                  const SizedBox(height: 12),
                  // Scrollable Queue list inside ConstrainedBox
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: state.isAutoMode
                          ? ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.remainingQueue.length - 1,
                              itemBuilder: (context, idx) {
                                final itemIdx = idx + 1;
                                final customer = state.remainingQueue[itemIdx];
                                final double prevLat = state.remainingQueue[idx].latitude!;
                                final double prevLng = state.remainingQueue[idx].longitude!;
                                final segment = OsmRouterService().findRoute(
                                  LatLng(prevLat, prevLng),
                                  LatLng(customer.latitude!, customer.longitude!),
                                );
                                final double distance = OsmRouterService().calculateRouteDistance(segment);
                                return QueueItemCard(
                                  index: itemIdx + totalCompleted,
                                  name: customer.name,
                                  address: customer.address,
                                  phone: customer.phone,
                                  distanceLabel: 'ระยะห่าง ~${distance.toStringAsFixed(2)} กม.',
                                  trailing: Icon(Icons.lock_clock, color: Colors.grey.shade400),
                                );
                              },
                            )
                          : ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: state.remainingQueue.length - 1,
                              onReorder: (oldIndex, newIndex) {
                                state.reorderQueue(oldIndex, newIndex);
                                setModalState(() {});
                              },
                              itemBuilder: (context, idx) {
                                final itemIdx = idx + 1;
                                final customer = state.remainingQueue[itemIdx];
                                final double prevLat = state.remainingQueue[idx].latitude!;
                                final double prevLng = state.remainingQueue[idx].longitude!;
                                final segment = OsmRouterService().findRoute(
                                  LatLng(prevLat, prevLng),
                                  LatLng(customer.latitude!, customer.longitude!),
                                );
                                final double distance = OsmRouterService().calculateRouteDistance(segment);
                                return QueueItemCard(
                                  key: ValueKey(customer.phone),
                                  index: itemIdx + totalCompleted,
                                  name: customer.name,
                                  address: customer.address,
                                  phone: customer.phone,
                                  distanceLabel: 'ระยะห่าง ~${distance.toStringAsFixed(2)} กม.',
                                  trailing: const Icon(Icons.drag_handle),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Reset Navigation Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      state.resetNavigation();
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: Text(
                      'ยกเลิกแผนการเดินทาง',
                      style: kanitTextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

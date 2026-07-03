import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import 'widgets/route_planning_content.dart';

export 'widgets/route_planning_content.dart';

class RoutePlanningPage extends StatelessWidget {
  const RoutePlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      Provider.of<AppStateProvider>(context, listen: false);
      return const RoutePlanningPageContent();
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const RoutePlanningPageContent(),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../core/design_tokens.dart';
import 'widgets/dashboard_map_content.dart';

/// หน้าหลักแดชบอร์ด (Dashboard Screen Entrypoint) ทำหน้าที่จัดการการดึงข้อมูลและแสดงสถานะ Loading/Error
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    try {
      final appState = Provider.of<AppStateProvider>(context);
      return _buildContent(context, appState);
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: Consumer<AppStateProvider>(
          builder: (context, appState, _) => _buildContent(context, appState),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, AppStateProvider appState) {
    if (appState.isLoading) {
      return const _LoadingView();
    }
    if (appState.error != null) {
      return _ErrorView(error: appState.error);
    }
    return DashboardMapContent(
      tripRecords: appState.trips,
      customerRecords: appState.customers,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error views
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด: ${error ?? 'ไม่ทราบสาเหตุ'}'),
          ],
        ),
      ),
    );
  }
}

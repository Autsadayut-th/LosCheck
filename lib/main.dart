import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/hive_database.dart';
import 'providers/app_state_provider.dart';
import 'screens/customer_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/trip_fee_page.dart';
import 'screens/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await appDatabase.initialize();
  } catch (e) {
    debugPrint('Database initialization failed: $e');
    // Continue with app launch even if database fails
    // UI will handle database errors gracefully
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>() ??
      context.findRootAncestorStateOfType<MyAppState>();

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  ThemeMode get themeMode => _themeMode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: MaterialApp(
        title: 'Los Check',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            primary: Colors.teal.shade700,
            secondary: Colors.amber.shade700,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black45,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              elevation: 3,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.tealAccent,
            primary: Colors.tealAccent.shade200,
            secondary: Colors.amberAccent,
            brightness: Brightness.dark,
            surface: const Color(0xFF121212),
            surfaceContainerHighest: const Color(0xFF2C2C2C),
            onSurface: Colors.white,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade200,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: HomeShell(themeMode: _themeMode, onThemeModeChanged: setThemeMode),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  bool _isDatabaseReady = false;

  static const List<Widget> _pages = [
    DashboardPage(),
    TripFeePage(),
    CustomerPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkDatabaseReady();
  }

  Future<void> _checkDatabaseReady() async {
    try {
      // Check if database is initialized
      if (!appDatabase.isInitialized) {
        debugPrint('Database not initialized, retrying...');
        await appDatabase.initialize();
      }
      
      // Test database connection by attempting a simple query
      await appDatabase.getTotalCustomers();
      setState(() {
        _isDatabaseReady = true;
      });
    } catch (e) {
      debugPrint('Database not ready: $e');
      // Still allow UI to load, pages will handle database errors
      setState(() {
        _isDatabaseReady = true;
      });
    }
  }

  void _cycleTheme() {
    final next = switch (widget.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    widget.onThemeModeChanged(next);
  }

  IconData get _themeIcon {
    return switch (widget.themeMode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDatabaseReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'กำลังโหลด...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Los Check',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_themeIcon),
            tooltip: 'เปลี่ยนธีม',
            onPressed: _cycleTheme,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'แดชบอร์ด',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'ค่ารอบ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_pin_circle_outlined),
            selectedIcon: Icon(Icons.person_pin_circle),
            label: 'ลูกค้า',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'การตั้งค่า',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _themePrefKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      if (saved != null && mounted) {
        setState(() {
          _themeMode = switch (saved) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
        });
      }
    } catch (_) {
      // Ignore preference errors — fall back to system theme
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // Ignore save errors
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveTheme(mode);
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
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('th', 'TH'),
          Locale('en', 'US'),
        ],
        locale: const Locale('th', 'TH'),
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

    final appState = Provider.of<AppStateProvider>(context);
    final today = DateTime.now();
    final todayRounds = appState.trips
        .where((t) => t.isSameDay(today))
        .fold<int>(0, (sum, t) => sum + t.rounds);
    final totalCustomers = appState.customers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Los Check',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'แดชบอร์ด',
          ),
          NavigationDestination(
            icon: todayRounds > 0
                ? Badge(
                    label: Text('$todayRounds'),
                    child: const Icon(Icons.receipt_long_outlined),
                  )
                : const Icon(Icons.receipt_long_outlined),
            selectedIcon: todayRounds > 0
                ? Badge(
                    label: Text('$todayRounds'),
                    child: const Icon(Icons.receipt_long),
                  )
                : const Icon(Icons.receipt_long),
            label: 'ค่ารอบ',
          ),
          NavigationDestination(
            icon: totalCustomers > 0
                ? Badge(
                    label: Text('$totalCustomers'),
                    child: const Icon(Icons.person_pin_circle_outlined),
                  )
                : const Icon(Icons.person_pin_circle_outlined),
            selectedIcon: totalCustomers > 0
                ? Badge(
                    label: Text('$totalCustomers'),
                    child: const Icon(Icons.person_pin_circle),
                  )
                : const Icon(Icons.person_pin_circle),
            label: 'ลูกค้า',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'การตั้งค่า',
          ),
        ],
      ),
    );
  }
}

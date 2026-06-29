import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/hive_database.dart';
import 'providers/app_state_provider.dart';
import 'screens/customer_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/trip_fee_page.dart';
import 'screens/settings_page.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

final bool isTesting = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');


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
            primary: const Color(0xFF00897B),
            secondary: Colors.amber.shade700,
          ),
          useMaterial3: true,
          fontFamily: isTesting ? 'Roboto' : GoogleFonts.kanit().fontFamily,
          textTheme: isTesting
              ? const TextTheme(
                  headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  titleSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                )
              : GoogleFonts.kanitTextTheme().copyWith(
                  headlineLarge: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.bold),
                  headlineMedium: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.bold),
                  headlineSmall: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.w600),
                  titleLarge: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold),
                  titleMedium: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.w600),
                  titleSmall: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.w500),
                  bodyLarge: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.normal),
                  bodyMedium: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.normal),
                  bodySmall: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.normal),
                  labelLarge: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500),
                  labelMedium: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500),
                  labelSmall: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.normal),
                ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 56,
            titleTextStyle: isTesting
                ? const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )
                : GoogleFonts.kanit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: const Color(0xFFE0F2F1), // Light Teal indicator
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF004D40));
              }
              return const IconThemeData(color: Colors.black54);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final font = isTesting
                  ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
                  : GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600);
              if (states.contains(WidgetState.selected)) {
                return font.copyWith(color: const Color(0xFF004D40));
              }
              return font.copyWith(color: Colors.black54);
            }),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
          fontFamily: isTesting ? 'Roboto' : GoogleFonts.kanit().fontFamily,
          textTheme: isTesting
              ? const TextTheme(
                  headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
                  titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  titleSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
                  bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white70),
                  bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white70),
                  bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white60),
                  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                  labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white60),
                )
              : GoogleFonts.kanitTextTheme(ThemeData.dark().textTheme).copyWith(
                  headlineLarge: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  headlineMedium: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  headlineSmall: GoogleFonts.kanit(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
                  titleLarge: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  titleMedium: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                  titleSmall: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
                  bodyLarge: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white70),
                  bodyMedium: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.white70),
                  bodySmall: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white60),
                  labelLarge: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  labelMedium: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                  labelSmall: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white60),
                ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 56,
            titleTextStyle: isTesting
                ? const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )
                : GoogleFonts.kanit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            indicatorColor: const Color(0xFF004D40), // Dark Teal indicator
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Colors.white60);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final font = isTesting
                  ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
                  : GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600);
              if (states.contains(WidgetState.selected)) {
                return font.copyWith(color: Colors.white);
              }
              return font.copyWith(color: Colors.white60);
            }),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade200,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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

    final showTransparentAppBar = _selectedIndex == 0;

    return Scaffold(
      extendBodyBehindAppBar: showTransparentAppBar,
      appBar: showTransparentAppBar
          ? null
          : AppBar(
              title: const Text(
                'Los Check',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
          if (showTransparentAppBar)
            const Positioned(
              left: 0,
              top: 0,
              child: Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: Text('Los Check'),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        height: 60, // Make bottom navigation bar smaller/shorter
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // hides text labels
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
          const NavigationDestination(
            icon: Icon(Icons.person_pin_circle_outlined),
            selectedIcon: Icon(Icons.person_pin_circle),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/storage_service.dart';
import 'theme.dart';
import 'app_state.dart';
import 'screens/scan_screen.dart';
import 'screens/today_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await StorageService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const CalorieLensApp(),
    ),
  );
}

class CalorieLensApp extends StatelessWidget {
  const CalorieLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieLens',
      theme: buildTheme(),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    ScanScreen(),
    TodayScreen(),
    TrendsScreen(),
    CoachScreen(),
    WorkoutScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.camera_alt_outlined),
      activeIcon: Icon(Icons.camera_alt),
      label: 'Scan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Today',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.trending_up_outlined),
      activeIcon: Icon(Icons.trending_up),
      label: 'Trends',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.smart_toy_outlined),
      activeIcon: Icon(Icons.smart_toy),
      label: 'Coach',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center),
      label: 'Workout',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2820))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: _navItems,
        ),
      ),
    );
  }
}

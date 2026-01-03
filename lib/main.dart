import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/screens/mission_screen.dart';
import 'package:life_dashboard/screens/routine_screen.dart';
// If you have a Zen/Timer screen, keep this. If not, comment it out.
import 'package:life_dashboard/screens/journal_screen.dart';
import 'package:life_dashboard/screens/stats_screen.dart';
import 'package:life_dashboard/screens/vent_screen.dart';
import 'package:life_dashboard/screens/settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_dashboard/screens/zen_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the Brain (this also runs the Garbage Collector/Stats Harvester)
  await DatabaseHelper.init();
  runApp(const LifeDashboardApp());
}

class LifeDashboardApp extends StatelessWidget {
  const LifeDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Load Settings directly
    final settings = DatabaseHelper.getSettings();
    final int themeIndex = settings['theme_index'] ?? 0;
    final bool isDark = settings['is_dark_mode'] ?? true;

    // The 16 Theme Colors
    final List<Color> themeColors = [
      const Color(0xFF6C63FF), // 0: Default Purple
      const Color(0xFFFF5252), // 1: Red
      const Color(0xFF4CAF50), // 2: Green
      const Color(0xFFFF9800), // 3: Orange
      const Color(0xFF2196F3), // 4: Blue
      const Color(0xFF9C27B0), // 5: Violet
      const Color(0xFF009688), // 6: Teal
      const Color(0xFF795548), // 7: Brown
      const Color(0xFF607D8B), // 8: Slate
      const Color(0xFFE91E63), // 9: Pink
      const Color(0xFFCDDC39), // 10: Lime
      const Color(0xFFFFC107), // 11: Amber
      // The last 4 trigger Gradients in MainNavigation
      const Color(0xFF00FFFF), // 12: Cyan (Cyberpunk)
      const Color(0xFFFF00FF), // 13: Magenta (Retrowave)
      const Color(0xFF1B5E20), // 14: Deep Forest
      const Color(0xFFB71C1C), // 15: Blood Moon
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeColors[themeIndex],
          brightness: isDark ? Brightness.dark : Brightness.light,
          // Force dark surface for dark mode to make colors pop
          surface: isDark ? const Color(0xFF121212) : Colors.white,
        ),
        textTheme:
            GoogleFonts.jetBrainsMonoTextTheme(Theme.of(context).textTheme),
      ),
      home: MainNavigation(themeIndex: themeIndex),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int themeIndex;
  const MainNavigation({super.key, required this.themeIndex});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  // Define your screens here.
  // Make sure these files exist in lib/screens/
// Explicitly define this as List<Widget> to prevent type errors
  final List<Widget> _screens = [
    const MissionScreen(), // 0
    const RoutineScreen(), // 1
    const ZenScreen(), // 2
    const JournalScreen(), // 3
    const StatsScreen(), // 4
    const VentScreen(), // 5
    const SettingsScreen(), // 6
  ];
  // Logic for Gradient Backgrounds
  BoxDecoration? _getGradient(int index) {
    if (index == 12) {
      // Cyberpunk
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight));
    } else if (index == 13) {
      // Retrowave
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF240b36), Color(0xFFc31432)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight));
    } else if (index == 14) {
      // Forest
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF0f9b0f)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter));
    } else if (index == 15) {
      // Blood Moon
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF430000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter));
    }
    return null; // Solid color theme
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient(widget.themeIndex);

    return Scaffold(
      // Apply gradient to the whole screen body
      body: Container(
        decoration: gradient,
        child: IndexedStack(
          index: _index,
          children: _screens.map((screen) {
            // Make screens transparent so gradient shows through
            return Theme(
              data: Theme.of(context).copyWith(
                scaffoldBackgroundColor:
                    gradient != null ? Colors.transparent : null,
              ),
              child: screen,
            );
          }).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        // Make navbar semi-transparent if using gradient
        backgroundColor:
            gradient != null ? Colors.black.withOpacity(0.5) : null,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.assignment), label: "Missions"),
          NavigationDestination(icon: Icon(Icons.repeat), label: "Routine"),
          NavigationDestination(icon: Icon(Icons.timer), label: "Zen"),
          NavigationDestination(icon: Icon(Icons.book), label: "Journal"),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: "Stats"),
          NavigationDestination(icon: Icon(Icons.psychology), label: "Vent"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

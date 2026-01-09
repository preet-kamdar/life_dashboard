import 'dart:math' as math;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/screens/dashboard_screen.dart';
import 'package:life_dashboard/screens/mission_screen.dart';
import 'package:life_dashboard/screens/routine_screen.dart';
import 'package:life_dashboard/screens/journal_screen.dart';
import 'package:life_dashboard/screens/stats_screen.dart';
import 'package:life_dashboard/screens/settings_screen.dart';
import 'package:life_dashboard/screens/zen_screen.dart';
import 'package:life_dashboard/screens/vent_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DatabaseHelper.init();
  } catch (e) {
    print("CRITICAL ERROR: Database failed to load: $e");
  }
  runApp(const LifeDashboardApp());
}

class LifeDashboardApp extends StatelessWidget {
  const LifeDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseHelper.getSettingsListenable(),
      builder: (context, box, _) {
        final settings = Map<String, dynamic>.from(box.toMap());
        final int themeIndex = settings['theme_index'] ?? 0;
        final bool isDark = settings['is_dark_mode'] ?? true;
        // NEW SETTING: Default to true
        final bool useWallpaper = settings['use_wallpaper_colors'] ?? true;

        final List<Color> themeColors = [
          const Color(0xFF6C63FF),
          const Color(0xFFFF5252),
          const Color(0xFF4CAF50),
          const Color(0xFFFF9800),
          const Color(0xFF2196F3),
          const Color(0xFF9C27B0),
          const Color(0xFF009688),
          const Color(0xFF795548),
          const Color(0xFF607D8B),
          const Color(0xFFE91E63),
          const Color(0xFFCDDC39),
          const Color(0xFFFFC107),
          const Color(0xFF00FFFF),
          const Color(0xFFFF00FF),
          const Color(0xFF1B5E20),
          const Color(0xFFB71C1C),
        ];

        return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
          ColorScheme? scheme;

          // LOGIC: Only use dynamic if available AND enabled by user
          if (useWallpaper && lightDynamic != null && darkDynamic != null) {
            scheme = isDark ? darkDynamic : lightDynamic;
          } else {
            // Fallback to manual selection
            scheme = ColorScheme.fromSeed(
              seedColor: themeColors[themeIndex],
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: isDark ? const Color(0xFF121212) : Colors.white,
            );
          }

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Life Dashboard',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: scheme,
              textTheme: GoogleFonts.outfitTextTheme().copyWith(
                headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                bodyMedium: GoogleFonts.outfit(),
                labelSmall: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold),
              ),
            ),
            home: MainNavigation(themeIndex: themeIndex),
          );
        });
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int themeIndex;
  const MainNavigation({super.key, required this.themeIndex});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isMenuOpen = false;
  late AnimationController _menuController;
  late Animation<double> _expandAnimation;

  final List<Widget> _screens = [
    const DashboardScreen(), // 0
    const MissionScreen(), // 1
    const RoutineScreen(), // 2
    const ZenScreen(), // 3
    const VentScreen(), // 4
    const JournalScreen(), // 5
    const StatsScreen(), // 6
    const SettingsScreen(), // 7
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.grid_view_rounded, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.flag_rounded, 'label': 'Missions', 'index': 1},
    {'icon': Icons.repeat_rounded, 'label': 'Protocol', 'index': 2},
    {'icon': Icons.self_improvement_rounded, 'label': 'Zen', 'index': 3},
    {'icon': Icons.psychology_rounded, 'label': 'Neural Link', 'index': 4},
    {'icon': Icons.terminal_rounded, 'label': 'Log', 'index': 5},
    {'icon': Icons.insights_rounded, 'label': 'Stats', 'index': 6},
    {'icon': Icons.tune_rounded, 'label': 'System', 'index': 7},
  ];

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _menuController.reverse();
    } else {
      _menuController.forward();
    }
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _isMenuOpen = false;
    });
    _menuController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    // Corner mode: active only on Journal(5) or Stats(6) to clear view
    final bool isCornerMode = _index == 5 || _index == 6;

    final double fabLeft =
        isCornerMode ? size.width - 80 - 24 : (size.width / 2) - 36;

    const double radius = 140.0;
    final otherItems = _menuItems.where((i) => i['index'] != _index).toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      body: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          IndexedStack(
            index: _index,
            children: _screens,
          ),
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedOpacity(
                opacity: _isMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  color: colorScheme.scrim.withOpacity(0.3),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          if (_isMenuOpen || _menuController.isAnimating)
            ...List.generate(otherItems.length, (i) {
              final item = otherItems[i];
              double startAngle;
              double totalAngle;

              if (isCornerMode) {
                startAngle = math.pi;
                totalAngle = math.pi / 2;
              } else {
                startAngle = math.pi * 0.98;
                totalAngle = math.pi * 0.96;
              }

              final double step = totalAngle / (otherItems.length - 1);
              final double angle = startAngle - (step * i);

              return AnimatedBuilder(
                animation: _expandAnimation,
                builder: (ctx, child) {
                  final double animValue = _expandAnimation.value;
                  final double r = radius * animValue;
                  final double dx = r * math.cos(angle);
                  final double dy = r * math.sin(angle);

                  return Positioned(
                    bottom: 50 + dy,
                    left:
                        (isCornerMode ? (size.width - 70) : (size.width / 2)) +
                            dx -
                            24,
                    child: Transform.scale(
                      scale: animValue,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            mini: true,
                            heroTag: 'menu_btn_${item['index']}',
                            onPressed: () => _selectTab(item['index'] as int),
                            elevation: 2,
                            backgroundColor: colorScheme.secondaryContainer,
                            foregroundColor: colorScheme.onSecondaryContainer,
                            child: Icon(item['icon'] as IconData, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.transparent,
                            child: Text(
                              item['label'] as String,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubicEmphasized,
            bottom: 40,
            left: fabLeft,
            child: SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton.large(
                onPressed: _toggleMenu,
                backgroundColor: _isMenuOpen
                    ? colorScheme.errorContainer
                    : colorScheme.primaryContainer,
                foregroundColor: _isMenuOpen
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: AnimatedRotation(
                  turns: _isMenuOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    _isMenuOpen
                        ? Icons.add
                        : _menuItems[_index]['icon'] as IconData,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

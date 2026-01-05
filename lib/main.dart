import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/screens/dashboard_screen.dart';
import 'package:life_dashboard/screens/mission_screen.dart';
import 'package:life_dashboard/screens/routine_screen.dart';
import 'package:life_dashboard/screens/journal_screen.dart';
import 'package:life_dashboard/screens/stats_screen.dart';
import 'package:life_dashboard/screens/settings_screen.dart';
import 'package:life_dashboard/screens/zen_screen.dart';

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

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Life Dashboard',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeColors[themeIndex],
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: isDark ? const Color(0xFF121212) : Colors.white,
            ),
          ),
          home: MainNavigation(themeIndex: themeIndex),
        );
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
  late Animation<double> _rotationAnimation;
  late Animation<double> _expandAnimation;

  final List<Widget> _screens = [
    const DashboardScreen(), // 0
    const MissionScreen(), // 1
    const RoutineScreen(), // 2
    const ZenScreen(), // 3
    const JournalScreen(), // 4 (THE SPECIAL PAGE)
    const StatsScreen(), // 5
    const SettingsScreen(), // 6
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.home_rounded, 'label': 'Home', 'index': 0},
    {'icon': Icons.assignment_rounded, 'label': 'Missions', 'index': 1},
    {'icon': Icons.repeat_rounded, 'label': 'Routine', 'index': 2},
    {'icon': Icons.timer_rounded, 'label': 'Zen', 'index': 3},
    {'icon': Icons.book_rounded, 'label': 'Journal', 'index': 4},
    {'icon': Icons.bar_chart_rounded, 'label': 'Stats', 'index': 5},
    {'icon': Icons.settings_rounded, 'label': 'Settings', 'index': 6},
  ];

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 400),
    );

    _rotationAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
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
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _isMenuOpen = false;
    });
    _menuController.reverse();
  }

  BoxDecoration? _getGradient(int index) {
    if (index == 12) {
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight));
    }
    if (index == 13) {
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF240b36), Color(0xFFc31432)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight));
    }
    if (index == 14) {
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF0f9b0f)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter));
    }
    if (index == 15) {
      return const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF000000), Color(0xFF430000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient(widget.themeIndex);
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    // --- LOGIC: IS THIS THE JOURNAL PAGE? ---
    final bool isCornerMode = _index == 4;

    // --- FAB POSITION CALCULATIONS ---
    // If Corner: 30px from right. If Center: Middle of screen.
    // We subtract 40px (half button width) to center it perfectly.
    final double fabLeft = isCornerMode
        ? size.width - 80 - 30 // Right Side (Screen - ButtonSize - Padding)
        : (size.width / 2) - 40; // Center

    // --- FAN MENU MATH ---
    final double radius = (size.width * 0.85) / 2;
    final otherItems = _menuItems.where((i) => i['index'] != _index).toList();

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: gradient,
        child: Stack(
          alignment: Alignment
              .bottomLeft, // Changed to allow precise coordinate mapping
          children: [
            // 1. CONTENT
            IndexedStack(
              index: _index,
              children: _screens
                  .map((s) => Theme(
                      data: Theme.of(context).copyWith(
                          scaffoldBackgroundColor:
                              gradient != null ? Colors.transparent : null),
                      child: s))
                  .toList(),
            ),

            // 2. DIMMER
            if (_isMenuOpen)
              GestureDetector(
                onTap: _toggleMenu,
                child: AnimatedOpacity(
                  opacity: _isMenuOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    color: colorScheme.scrim.withOpacity(0.4),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

            // 3. SATELLITE BUTTONS (FAN MENU)
            if (_isMenuOpen || _menuController.isAnimating)
              ...List.generate(otherItems.length, (i) {
                final item = otherItems[i];

                // --- CONTEXT AWARE MENU ANGLES ---
                double startAngle;
                double totalAngle;

                if (isCornerMode) {
                  // CORNER MODE: 90 Degree Quadrant (Pi/2)
                  // Starts from Left (Pi) -> Goes to Up (Pi/2)
                  startAngle = math.pi;
                  totalAngle = math.pi / 2;
                } else {
                  // CENTER MODE: 180 Degree Arch
                  startAngle = math.pi * 0.94;
                  totalAngle = math.pi * 0.88;
                }

                final double step = totalAngle / (otherItems.length - 1);
                // In corner mode, we subtract step to go from Left(180) to Up(90)
                final double angle = startAngle - (step * i);

                return AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (ctx, child) {
                    final double animValue = _expandAnimation.value;
                    final double r = radius * animValue;
                    final double dx = r * math.cos(angle);
                    final double dy = r * math.sin(angle);

                    return Positioned(
                      // ANCHOR POINT:
                      // If Corner: Anchor is the new FAB position (Right side)
                      // If Center: Anchor is center screen
                      bottom: 50 + dy,
                      left: (isCornerMode
                              ? (size.width - 70)
                              : (size.width / 2)) +
                          dx -
                          30,

                      child: Transform.scale(
                        scale: animValue > 1.1 ? 1.1 : animValue,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: FloatingActionButton(
                                heroTag: 'menu_btn_${item['index']}',
                                onPressed: () =>
                                    _selectTab(item['index'] as int),
                                elevation: 3,
                                backgroundColor: colorScheme.secondaryContainer,
                                foregroundColor:
                                    colorScheme.onSecondaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(item['icon'] as IconData, size: 26),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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

            // 4. MAIN REACTOR BUTTON (The Drifting Button)
            AnimatedPositioned(
              // "Drift" Animation Logic
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic, // Smooth drift
              bottom: 30,
              left: fabLeft, // Calculated above

              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * math.pi,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: FloatingActionButton.large(
                        onPressed: _toggleMenu,
                        backgroundColor: _isMenuOpen
                            ? colorScheme.surfaceContainer
                            : colorScheme.primaryContainer,
                        foregroundColor: _isMenuOpen
                            ? colorScheme.onSurface
                            : colorScheme.onPrimaryContainer,
                        elevation: _isMenuOpen ? 2 : 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        child: Icon(
                          _isMenuOpen
                              ? Icons.close
                              : _menuItems[_index]['icon'] as IconData,
                          size: 36,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

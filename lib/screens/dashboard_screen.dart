import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/screens/vent_screen.dart';
import 'package:life_dashboard/screens/journal_screen.dart';
import 'package:life_dashboard/screens/stats_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _missions = [];
  List<Map<String, dynamic>> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Reloads database content
    final missions = DatabaseHelper.loadMissions();
    final routines = DatabaseHelper.loadRoutine();
    if (mounted) {
      setState(() {
        _missions = missions;
        _routines = routines;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _loadData());
  }

  // --- ACTIONS (Simplified for brevity, logic remains same) ---
  void _deleteRoutine(int index) {
    final updatedList = List<Map<String, dynamic>>.from(_routines);
    updatedList.removeAt(index);
    DatabaseHelper.saveRoutine(updatedList);
    _loadData();
  }

  void _toggleRoutine(int index, bool? value) {
    final updatedList = List<Map<String, dynamic>>.from(_routines);
    updatedList[index]['isCompleted'] = value;
    DatabaseHelper.saveRoutine(updatedList);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings to get the user name live!
    return ValueListenableBuilder(
      valueListenable: DatabaseHelper.getSettingsListenable(),
      builder: (context, box, _) {
        final settings = Map<String, dynamic>.from(box.toMap());
        final username = settings['user_name'] ?? 'User';
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // 1. ANDROID 16 HEADER
              SliverAppBar.large(
                title: Text("${_getGreeting()},\n$username"),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.person,
                          color: colorScheme.onPrimaryContainer, size: 20),
                    ),
                    onPressed: () {}, // Profile action placeholder
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              // 2. QUICK ACTIONS (The "Dock" Reimagined)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildActionChip(
                          context,
                          "Vent",
                          Icons.psychology,
                          colorScheme.tertiaryContainer,
                          colorScheme.onTertiaryContainer,
                          () => _navigateTo(const VentScreen())),
                      const SizedBox(width: 12),
                      _buildActionChip(
                          context,
                          "Log",
                          Icons.edit_note,
                          colorScheme.secondaryContainer,
                          colorScheme.onSecondaryContainer,
                          () => _navigateTo(const JournalScreen())),
                      const SizedBox(width: 12),
                      _buildActionChip(
                          context,
                          "Stats",
                          Icons.bar_chart,
                          colorScheme.surfaceContainerHigh,
                          colorScheme.onSurface,
                          () => _navigateTo(const StatsScreen())),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 3. ROUTINES SECTION
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text("Daily Protocols",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _routines[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Dismissible(
                        key: Key(item['id'] ?? index.toString()),
                        onDismissed: (_) => _deleteRoutine(index),
                        background: Container(
                          decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete,
                              color: colorScheme.onErrorContainer),
                        ),
                        child: Card(
                          elevation: 0,
                          color: item['isCompleted']
                              ? colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5)
                              : colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(item['title'],
                                style: TextStyle(
                                  decoration: item['isCompleted']
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item['isCompleted']
                                      ? colorScheme.onSurface.withOpacity(0.5)
                                      : colorScheme.onSurface,
                                )),
                            value: item['isCompleted'],
                            onChanged: (val) => _toggleRoutine(index, val),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _routines.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 4. MISSIONS SECTION
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Active Objectives",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      // No explicit add button here needed if FAB exists, but keeping header clean
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = _missions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Card(
                        elevation: 0,
                        color: colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.surface,
                            child: Icon(Icons.play_arrow_rounded,
                                color: colorScheme.primary),
                          ),
                          title: Text(m['title'],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer)),
                          subtitle: Text("Duration: ${m['duration']}",
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer
                                      .withOpacity(0.7))),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  "Go to Missions Tab to manage operations"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 1),
                            ));
                          },
                        ),
                      ).animate().fadeIn().slideX(),
                    );
                  },
                  childCount: _missions.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionChip(BuildContext context, String label, IconData icon,
      Color bg, Color fg, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

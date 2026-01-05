import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:life_dashboard/screens/mission_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // A unified list of everything happening today
  List<TimelineItem> _timeline = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final missions = DatabaseHelper.loadMissions();
    final routines = DatabaseHelper.loadRoutine();
    final journal = DatabaseHelper.loadJournal();

    List<TimelineItem> items = [];

    // 1. Convert JOURNAL entries to Timeline Items
    for (var j in journal) {
      // Parse the ISO date string
      DateTime dt = DateTime.tryParse(j['date']) ?? DateTime.now();
      items.add(TimelineItem(
        type: TimelineType.journal,
        time: dt,
        title: j['title'],
        subtitle: j['id'].toString().substring(0, 7), // The Git Hash
        data: j,
      ));
    }

    // 2. Convert ROUTINES to Timeline Items
    // Since routines don't have timestamps in your DB yet, we'll simulate them
    // spreading through the day or group them at "Now" for visibility.
    // For this prototype, we'll assign them a "Target Time" based on index to show the flow.
    DateTime routineBaseTime =
        DateTime.now().subtract(const Duration(hours: 4));
    for (var i = 0; i < routines.length; i++) {
      var r = routines[i];
      items.add(TimelineItem(
        type: TimelineType.routine,
        time: routineBaseTime
            .add(Duration(hours: i)), // Fake spread for visual demo
        title: r['title'],
        subtitle: r['isCompleted'] ? "Completed" : "Pending Protocol",
        isCompleted: r['isCompleted'],
        data: r,
        index: i, // Needed for toggling
      ));
    }

    // 3. Convert MISSIONS to Timeline Items
    for (var m in missions) {
      // Missions usually don't have a specific "start time" saved in the basic DB helper
      // So we will default them to "Now" to keep them visible at the top/center
      items.add(TimelineItem(
        type: TimelineType.mission,
        time: DateTime.now(), // Always relevant "Now"
        title: m['title'],
        subtitle: "${m['duration']} minutes",
        data: m,
      ));
    }

    // 4. SORT CHRONOLOGICALLY (Newest First)
    items.sort((a, b) => b.time.compareTo(a.time));

    if (mounted) {
      setState(() {
        _timeline = items;
      });
    }
  }

  // --- ACTIONS ---
  void _toggleRoutine(int index, bool? value) async {
    // We need to find the actual routine list index
    final routines = DatabaseHelper.loadRoutine();
    // In a real app, use IDs. Here we trust the index passed from the item.
    if (index < routines.length) {
      routines[index]['isCompleted'] = value;
      await DatabaseHelper.saveRoutine(routines);
      _loadData(); // Reload to refresh timeline UI
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. MODERN HEADER
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(now).toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: colorScheme.primary,
                  ),
                ),
                Text(DateFormat('MMMM d').format(now)),
              ],
            ),
            centerTitle: false,
          ),

          // 2. THE TIMELINE STREAM
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _timeline[index];
                  final isLast = index == _timeline.length - 1;

                  return _buildTimelineRow(context, item, isLast);
                },
                childCount: _timeline.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
      BuildContext context, TimelineItem item, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(item.time);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. TIME COLUMN
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 16), // Align with top of card
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // B. THE LINE & DOT
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The Line
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 19, // Center of width 40
                  child: Container(
                    width: 2,
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                // The Dot (Icon)
                Container(
                  margin: const EdgeInsets.only(top: 14), // Align with card top
                  width: 20, // slightly bigger than journal line
                  height: 20,
                  decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getTypeColor(item.type, colorScheme),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.surface,
                          blurRadius: 4,
                          spreadRadius: 2,
                        )
                      ]),
                ),
              ],
            ),
          ),

          // C. THE CONTENT CARD
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildItemCard(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(TimelineType type, ColorScheme scheme) {
    switch (type) {
      case TimelineType.mission:
        return scheme.primary;
      case TimelineType.routine:
        return scheme.secondary;
      case TimelineType.journal:
        return scheme.tertiary;
    }
  }

  Widget _buildItemCard(BuildContext context, TimelineItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    // --- 1. MISSION CARD ---
    if (item.type == TimelineType.mission) {
      return InkWell(
        onTap: () => _navigateTo(const MissionScreen()),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_rounded,
                      size: 16, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text("ACTIVE OBJECTIVE",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color:
                              colorScheme.onPrimaryContainer.withOpacity(0.7))),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer)),
              Text("Target Duration: ${item.subtitle}",
                  style: TextStyle(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8))),
            ],
          ),
        ),
      );
    }

    // --- 2. ROUTINE CARD ---
    if (item.type == TimelineType.routine) {
      final isDone = item.isCompleted;
      return InkWell(
        onTap: () => _toggleRoutine(item.index!, !isDone),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: isDone
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone ? Colors.transparent : colorScheme.outlineVariant,
              )),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.circle_outlined,
                color: isDone
                    ? colorScheme.secondary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- 3. JOURNAL CARD ---
    if (item.type == TimelineType.journal) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface, // Blend with bg
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("commit ${item.subtitle}",
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// --- HELPER CLASSES ---

enum TimelineType { mission, routine, journal }

class TimelineItem {
  final TimelineType type;
  final DateTime time;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final dynamic data;
  final int? index; // Only for routines to toggle them

  TimelineItem({
    required this.type,
    required this.time,
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.data,
    this.index,
  });
}

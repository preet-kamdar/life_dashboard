import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<DateTime, int> _heatMapDataSet = {};
  int _totalFocusMinutes = 0;
  int _totalCommits = 0;
  String _currentRank = "Recruit";

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final minutes = DatabaseHelper.getTotalFocusMinutes();
    final journal = DatabaseHelper.loadJournal();

    // BUILD HEATMAP
    Map<DateTime, int> heatMap = {};
    for (var entry in journal) {
      try {
        String dateStr = entry['date'].split(' ')[0];
        DateTime date = DateTime.parse(dateStr);
        heatMap[date] = (heatMap[date] ?? 0) + 1;
      } catch (e) {
        // Ignore
      }
    }

    // CALCULATE RANK
    // Simple Gamification Formula
    int score = minutes + (journal.length * 10);
    String rank;
    if (score < 100) {
      rank = "Recruit";
    } else if (score < 500)
      rank = "Soldier";
    else if (score < 1000)
      rank = "Sergeant";
    else if (score < 5000)
      rank = "Captain";
    else
      rank = "Commander";

    setState(() {
      _totalFocusMinutes = minutes;
      _totalCommits = journal.length;
      _heatMapDataSet = heatMap;
      _currentRank = rank;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Dynamic Background (Matches Wallpaper/Theme)
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text("SYSTEM MONITOR",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER CARD (RANK) ---
            _buildRankCard(context),
            const SizedBox(height: 30),

            // --- THE HEATMAP (GIT GRAPH) ---
            Text("ACTIVITY LOG",
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer, // M3 Container Color
                borderRadius: BorderRadius.circular(24),
              ),
              child: HeatMap(
                datasets: _heatMapDataSet,
                colorMode: ColorMode.opacity,
                showText: false,
                scrollable: true,
                colorsets: {
                  1: colorScheme.primary, // Use Theme Color
                },
                onClick: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Activity on $value: ${_heatMapDataSet[value] ?? 0} commits")));
                },
                startDate: DateTime.now().subtract(const Duration(days: 90)),
                endDate: DateTime.now(),
                size: 20,
                fontSize: 10,
                textColor: colorScheme.onSurface,
                defaultColor:
                    colorScheme.surfaceContainerHighest, // Empty squares
              ),
            ),

            const SizedBox(height: 30),

            // --- STATS GRID ---
            Row(
              children: [
                Expanded(
                    child: _buildStatBox(context, "UPTIME (MINS)",
                        "$_totalFocusMinutes", Icons.timer)),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildStatBox(context, "TOTAL COMMITS",
                        "$_totalCommits", Icons.code)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rankColor = _getRankColor(colorScheme);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border(left: BorderSide(color: rankColor, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CURRENT CLEARANCE LEVEL",
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_currentRank.toUpperCase(),
                  style: TextStyle(
                      color: rankColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              Icon(Icons.shield, color: rankColor, size: 40),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.7, // Dynamic progress logic can go here later
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: rankColor,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(
      BuildContext context, String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary.withOpacity(0.7), size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getRankColor(ColorScheme scheme) {
    // Dynamic Rank Colors based on the Theme!
    if (_currentRank == "Recruit") return scheme.outline;
    if (_currentRank == "Soldier") return scheme.secondary;
    if (_currentRank == "Sergeant") return scheme.primary;
    if (_currentRank == "Captain") return scheme.tertiary;
    return scheme.error; // Commander (Red/Intense)
  }
}

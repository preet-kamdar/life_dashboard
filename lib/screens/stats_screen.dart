import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Stats Data
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
    // 1. Get Focus Minutes
    final minutes = DatabaseHelper.getTotalFocusMinutes();

    // 2. Get Journal Commits for Heatmap
    final journal = DatabaseHelper.loadJournal();
    Map<DateTime, int> heatMap = {};

    for (var entry in journal) {
      // Parse "2024-10-21 14:30" -> DateTime
      try {
        String dateStr = entry['date'].split(' ')[0]; // Just the YYYY-MM-DD
        DateTime date = DateTime.parse(dateStr);

        // Increment count for this date
        heatMap[date] = (heatMap[date] ?? 0) + 1;
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // 3. Calculate Rank
    // Logic: Every 60 minutes = 1 Level? Or based on commits?
    // Let's do: Total "Activity" Points.
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("SYSTEM MONITOR",
            style: TextStyle(letterSpacing: 2, fontFamily: 'monospace')),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER CARD (RANK) ---
            _buildRankCard(),
            const SizedBox(height: 30),

            // --- THE HEATMAP (GIT GRAPH) ---
            const Text("ACTIVITY LOG (CONTRIBUTIONS)",
                style: TextStyle(
                    color: Colors.grey, fontSize: 12, fontFamily: 'monospace')),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: HeatMap(
                datasets: _heatMapDataSet,
                colorMode: ColorMode.opacity,
                showText: false,
                scrollable: true,
                colorsets: const {
                  1: Colors.greenAccent,
                },
                onClick: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Activity on $value: ${_heatMapDataSet[value] ?? 0} commits")));
                },
                startDate: DateTime.now()
                    .subtract(const Duration(days: 90)), // Show last 3 months
                endDate: DateTime.now(),
                size: 20,
                fontSize: 10,
                textColor: Colors.white,
                defaultColor: Colors.white10,
              ),
            ),

            const SizedBox(height: 30),

            // --- STATS GRID ---
            Row(
              children: [
                Expanded(
                    child: _buildStatBox(
                        "UPTIME (MINS)", "$_totalFocusMinutes", Icons.timer)),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildStatBox(
                        "TOTAL COMMITS", "$_totalCommits", Icons.code)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(left: BorderSide(color: _getRankColor(), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CURRENT CLEARANCE LEVEL",
              style: TextStyle(
                  color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_currentRank.toUpperCase(),
                  style: TextStyle(
                      color: _getRankColor(),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              Icon(Icons.shield, color: _getRankColor(), size: 40),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: 0.7, // Dynamic progress later
            backgroundColor: Colors.white10,
            color: _getRankColor(),
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getRankColor() {
    if (_currentRank == "Recruit") return Colors.grey;
    if (_currentRank == "Soldier") return Colors.blueAccent;
    if (_currentRank == "Sergeant") return Colors.greenAccent;
    if (_currentRank == "Captain") return Colors.orangeAccent;
    return Colors.redAccent; // Commander
  }
}

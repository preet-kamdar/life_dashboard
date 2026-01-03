import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/screens/vent_screen.dart';
import 'package:life_dashboard/screens/journal_screen.dart';
import 'package:life_dashboard/screens/stats_screen.dart';
// Make sure you have this or remove the link
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _missions = [];
  List<Map<String, dynamic>> _routines = [];
  String _greeting = "WELCOME BACK";

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _loadData();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = "GOOD MORNING";
    } else if (hour < 17)
      _greeting = "GOOD AFTERNOON";
    else
      _greeting = "GOOD EVENING";
  }

  Future<void> _loadData() async {
    final missions = DatabaseHelper.loadMissions();
    final routines = DatabaseHelper.loadRoutine();
    setState(() {
      _missions = missions;
      _routines = routines;
    });
  }

  // --- ACTIONS ---

  void _addMission(String title, String durationStr) {
    final newMission = {
      'id': const Uuid().v4(),
      'title': title,
      'duration': durationStr, // e.g. "30 min"
      'remainingSeconds': _parseDuration(durationStr),
      'status': 'pending',
      'isCompleted': false,
    };

    final updatedList = [..._missions, newMission];
    DatabaseHelper.saveMissions(updatedList);
    _loadData();
  }

  void _addRoutine(String title) {
    final newRoutine = {
      'id': const Uuid().v4(),
      'title': title,
      'isCompleted': false,
    };

    final updatedList = [..._routines, newRoutine];
    DatabaseHelper.saveRoutine(updatedList);
    _loadData();
  }

  void _toggleRoutine(int index, bool? value) {
    final updatedList = List<Map<String, dynamic>>.from(_routines);
    updatedList[index]['isCompleted'] = value;
    DatabaseHelper.saveRoutine(updatedList);
    _loadData();
  }

  void _deleteRoutine(int index) {
    final updatedList = List<Map<String, dynamic>>.from(_routines);
    updatedList.removeAt(index);
    DatabaseHelper.saveRoutine(updatedList);
    _loadData();
  }

  int _parseDuration(String d) {
    // Basic parser: "30" -> 1800, "1h" -> 3600
    final clean = d.replaceAll(RegExp(r'[^0-9]'), '');
    int mins = int.tryParse(clean) ?? 30;
    return mins * 60;
  }

  // --- NAVIGATION HELPERS ---
  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _loadData()); // Refresh when coming back
  }

  // --- DIALOGS ---
  void _showAddDialog({required bool isMission}) {
    final titleController = TextEditingController();
    final durationController = TextEditingController(text: "30 min");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(isMission ? "NEW OPERATION" : "NEW PROTOCOL",
            style:
                const TextStyle(color: Colors.white, fontFamily: 'monospace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Title",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
              autofocus: true,
            ),
            if (isMission)
              TextField(
                controller: durationController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Duration (e.g., 30 min)",
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                if (isMission) {
                  _addMission(titleController.text, durationController.text);
                } else {
                  _addRoutine(titleController.text);
                }
                Navigator.pop(context);
              }
            },
            child: const Text("CONFIRM",
                style: TextStyle(
                    color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("LIFE OS v1.0",
            style: TextStyle(
                fontFamily: 'monospace', letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
        actions: [
          // If you have a settings screen, link it here. If not, comment this out.
          IconButton(
              icon: const Icon(Icons.settings, color: Colors.grey),
              onPressed: () {
                // _navigateTo(const SettingsScreen());
              }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GREETING
            Text("$_greeting, CAPTAIN.",
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1,
                    fontFamily: 'monospace')),
            const SizedBox(height: 20),

            // --- THE DOCK (SECTOR LINKS) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDockItem(Icons.psychology, "VENT", Colors.cyanAccent,
                    () => _navigateTo(const VentScreen())),
                _buildDockItem(Icons.terminal, "LOG", Colors.greenAccent,
                    () => _navigateTo(const JournalScreen())),
                _buildDockItem(Icons.bar_chart, "STATS", Colors.orangeAccent,
                    () => _navigateTo(const StatsScreen())),
              ],
            ),
            const SizedBox(height: 30),

            // --- ROUTINES ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("DAILY PROTOCOLS",
                    style:
                        TextStyle(color: Colors.grey, fontFamily: 'monospace')),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.grey, size: 20),
                  onPressed: () => _showAddDialog(isMission: false),
                )
              ],
            ),
            _routines.isEmpty
                ? _buildEmptyState("No active protocols.")
                : Column(
                    children: _routines.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Dismissible(
                        key: Key(item['id']),
                        background: Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete)),
                        onDismissed: (_) => _deleteRoutine(index),
                        child: CheckboxListTile(
                          activeColor: Colors.cyanAccent,
                          checkColor: Colors.black,
                          title: Text(item['title'],
                              style: TextStyle(
                                  color: item['isCompleted']
                                      ? Colors.white30
                                      : Colors.white,
                                  decoration: item['isCompleted']
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontFamily: 'monospace')),
                          value: item['isCompleted'],
                          onChanged: (val) => _toggleRoutine(index, val),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 30),

            // --- MISSIONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ACTIVE OPERATIONS",
                    style:
                        TextStyle(color: Colors.grey, fontFamily: 'monospace')),
                IconButton(
                  icon:
                      const Icon(Icons.add, color: Colors.cyanAccent, size: 20),
                  onPressed: () => _showAddDialog(isMission: true),
                )
              ],
            ),
            _missions.isEmpty
                ? _buildEmptyState("No active missions. Standby.")
                : ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _missions.length,
                    itemBuilder: (context, index) {
                      final mission = _missions[index];
                      return _buildMissionCard(mission);
                    },
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(isMission: true),
      ),
    );
  }

  Widget _buildDockItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withOpacity(0.3))),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontFamily: 'monospace'))
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white10, fontFamily: 'monospace'))),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> mission) {
    return Card(
      color: const Color(0xFF111111),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text("Go to the MISSIONS tab to control active operations."),
            duration: Duration(seconds: 2),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withOpacity(0.1),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.cyanAccent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 5),
                    Text("Duration: ${mission['duration']}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white10, size: 16)
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }
}

import 'dart:ui'; // REQUIRED FOR IMAGEFILTER
import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/widgets/time_picker_sheet.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  List<Map<String, dynamic>> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  void _loadRoutine() =>
      setState(() => _routines = DatabaseHelper.loadRoutine());

  // --- NEW: THE DIALOG ADD FUNCTION (FIXED) ---
  void _showAddRoutineDialog(BuildContext context) {
    final TextEditingController dialogController = TextEditingController();
    int dialogDuration = 0;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder allows the dialog to update itself (e.g., show time chip)
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHigh,
            title: const Text("New Protocol",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: dialogController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "E.g., Morning Workout",
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // --- FIX APPLIED HERE: Shortened text + Better Layout ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Duration:",
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold)),

                    // Time Picker Button / Chip
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16,
                          color: dialogDuration > 0
                              ? colorScheme.primary
                              : colorScheme.onSurface),
                      label: Text(
                          dialogDuration > 0
                              ? formatDuration(dialogDuration)
                              : "Set Time",
                          style: TextStyle(
                              color: dialogDuration > 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: dialogDuration > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      backgroundColor: dialogDuration > 0
                          ? colorScheme.primaryContainer
                          : null,
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (c) => TimePickerSheet(onTimeSet: (s) {
                                  // Update dialog state only
                                  setStateDialog(() => dialogDuration = s);
                                }));
                      },
                    ),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              FilledButton(
                onPressed: () {
                  if (dialogController.text.isNotEmpty) {
                    setState(() {
                      _routines.add({
                        'title': dialogController.text,
                        'isCompleted': false,
                        'duration': dialogDuration
                      });
                      DatabaseHelper.saveRoutine(_routines);
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Initiate"),
              ),
            ],
          );
        });
      },
    );
  }

  void _toggleRoutine(int index) {
    setState(() {
      _routines[index]['isCompleted'] = !_routines[index]['isCompleted'];
      DatabaseHelper.saveRoutine(_routines);
    });
  }

  void _deleteRoutine(int index) {
    setState(() {
      _routines.removeAt(index);
      DatabaseHelper.saveRoutine(_routines);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Daily Protocol",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // --- FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoutineDialog(context),
        label: const Text("NEW PROTOCOL",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        icon: const Icon(Icons.add),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            20, 10, 20, 80), // Bottom padding for FAB space
        children: [
          if (_routines.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.0),
                child: Text("SYSTEM IDLE // NO PROTOCOLS",
                    style: TextStyle(
                        color: Colors.white24,
                        letterSpacing: 2,
                        fontFamily: 'Courier',
                        fontSize: 12)),
              ),
            ),
          ..._routines.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> routine = entry.value;
            String title = routine['title'] ?? "Untitled";
            bool isLit = routine['isCompleted'] ?? false;
            int duration = routine['duration'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () => _toggleRoutine(index),
                onSecondaryTapUp: (details) {
                  showMenu(
                    context: context,
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
                    elevation: 10,
                    position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx + 10,
                        details.globalPosition.dy + 10),
                    items: [
                      const PopupMenuItem(
                          value: 'delete', child: Text("Delete Protocol"))
                    ],
                  ).then((value) {
                    if (value == 'delete') _deleteRoutine(index);
                  });
                },
                // --- THE SUPER FROSTED GLASS ---
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 25.0,
                        sigmaY: 25.0), // HIGH BLUR matching reference
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        // LIT: Theme Tint | UNLIT: Milky White Translucency (Icy look)
                        color: isLit
                            ? colorScheme.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.12),
                        border: Border.all(
                          // LIT: Theme glow | UNLIT: Crisp white edge
                          color: isLit
                              ? colorScheme.primary.withOpacity(0.6)
                              : Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isLit
                            ? [
                                BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: -5)
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          // Status Light
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isLit ? colorScheme.primary : Colors.white24,
                              shape: BoxShape.circle,
                              boxShadow: isLit
                                  ? [
                                      BoxShadow(
                                          color: colorScheme.primary,
                                          blurRadius: 10,
                                          spreadRadius: 1)
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  style: TextStyle(
                                    // Lit: White | Unlit: Slightly dimmed white
                                    color: isLit
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.85),
                                    fontWeight: isLit
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    letterSpacing: 1.5, fontSize: 15,
                                    shadows: isLit
                                        ? [
                                            Shadow(
                                                color: colorScheme.primary,
                                                blurRadius: 15)
                                          ]
                                        : [],
                                  ),
                                ),
                                if (duration > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      "DURATION: ${formatDuration(duration)}",
                                      style: TextStyle(
                                        color: isLit
                                            ? colorScheme.primary
                                            : Colors.white38,
                                        fontSize: 10,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Icon
                          Icon(isLit ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color:
                                  isLit ? colorScheme.primary : Colors.white24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

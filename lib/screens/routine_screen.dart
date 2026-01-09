import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
// Note: If you have a separate widget file for time_picker_sheet, keep it.
// If not, I can provide a simple inline one. Assuming it exists based on previous files.
import 'package:life_dashboard/widgets/time_picker_sheet.dart';

// Helper for formatting duration if not already globally available
String formatDuration(int totalSeconds) {
  int m = (totalSeconds % 3600) ~/ 60;
  int h = totalSeconds ~/ 3600;
  if (h > 0) return '${h}h ${m}m';
  return '$m min';
}

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

  void _showAddRoutineDialog(BuildContext context) {
    final TextEditingController dialogController = TextEditingController();
    int dialogDuration = 0;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHigh,
            title: const Text("New Protocol",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dialogController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "E.g., Morning Workout",
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Duration:",
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16,
                          color: dialogDuration > 0
                              ? colorScheme.primary
                              : colorScheme.onSurface),
                      label: Text(dialogDuration > 0
                          ? formatDuration(dialogDuration)
                          : "Set Time"),
                      onPressed: () {
                        // Ensure TimePickerSheet exists or use a simple fallback
                        try {
                          showModalBottomSheet(
                              context: context,
                              builder: (c) => TimePickerSheet(onTimeSet: (s) {
                                    setStateDialog(() => dialogDuration = s);
                                  }));
                        } catch (e) {
                          // Fallback if widget is missing
                          setStateDialog(
                              () => dialogDuration = 1800); // Default 30 mins
                        }
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
      backgroundColor:
          Colors.transparent, // Allows Main BG to show if set, else Surface
      appBar: AppBar(
        title: Text("DAILY PROTOCOL",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoutineDialog(context),
        label: const Text("NEW PROTOCOL"),
        icon: const Icon(Icons.add),
      ),
      body: _routines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.layers_clear,
                      size: 64, color: colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text("SYSTEM IDLE // NO PROTOCOLS",
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colorScheme.outline)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final routine = _routines[index];
                final title = routine['title'] ?? "Untitled";
                final isLit = routine['isCompleted'] ?? false;
                final duration = routine['duration'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Dismissible(
                    key: UniqueKey(),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteRoutine(index),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.delete,
                          color: colorScheme.onErrorContainer),
                    ),
                    child: GestureDetector(
                      onTap: () => _toggleRoutine(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(
                              // UNLIT: Subtle tinted glass | LIT: Strong primary color
                              color: isLit
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest
                                      .withOpacity(0.3),
                              border: Border.all(
                                color: isLit
                                    ? colorScheme.primary.withOpacity(0.5)
                                    : colorScheme.outlineVariant
                                        .withOpacity(0.2),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                // CHECKBOX INDICATOR
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      color: isLit
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isLit
                                              ? colorScheme.primary
                                              : colorScheme.outline,
                                          width: 2)),
                                  child: isLit
                                      ? Icon(Icons.check,
                                          size: 16,
                                          color: colorScheme.onPrimary)
                                      : null,
                                ),
                                const SizedBox(width: 16),

                                // TEXT CONTENT
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: isLit
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          decoration: isLit
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor: colorScheme
                                              .onPrimaryContainer
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      if (duration > 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            "DURATION: ${formatDuration(duration)}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                    color: isLit
                                                        ? colorScheme
                                                            .onPrimaryContainer
                                                            .withOpacity(0.7)
                                                        : colorScheme.outline),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

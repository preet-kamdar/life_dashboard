import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:life_dashboard/widgets/time_picker_sheet.dart';

// --- ADDED MISSING HELPER FUNCTION ---
String formatDuration(int totalSeconds) {
  int h = totalSeconds ~/ 3600;
  int m = (totalSeconds % 3600) ~/ 60;
  int s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});
  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _missions = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadMissions();
    // Global Ticker: Runs every second to update UI
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _tick();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _loadMissions() {
    setState(() {
      var rawMissions = DatabaseHelper.loadMissions();
      final seenIds = <String>{};
      _missions = rawMissions.where((m) {
        final id = m['id']?.toString() ?? DateTime.now().toString();
        return seenIds.add(id);
      }).toList();
    });
  }

  void _tick() {
    bool changed = false;
    for (var m in _missions) {
      // Logic: Only decrement if running and time remains
      if (m['isRunning'] == true && (m['remainingSeconds'] ?? 0) > 0) {
        m['remainingSeconds']--;

        // --- MOMENT OF VICTORY ---
        if (m['remainingSeconds'] <= 0) {
          m['remainingSeconds'] = 0;
          m['isRunning'] = false;
          m['isCompleted'] = true;

          // HARVEST STATS IMMEDIATELY
          int durationMins = (m['totalSeconds'] ?? 0) ~/ 60;
          if (durationMins < 1) durationMins = 1; // Minimum 1 min credit

          // Fire and forget (save to global stats)
          DatabaseHelper.addFocusMinutes(durationMins);
          DatabaseHelper.incrementMissionsCrushed(1);

          // Optional: Show a snackbar or sound here later
        }
        changed = true;
      }
    }

    if (changed) {
      setState(() {});
      // Auto-save every 5 seconds
      if (DateTime.now().second % 5 == 0) {
        DatabaseHelper.saveMissions(_missions);
      }
    }
  }

  void _toggleMissionState(int index) {
    setState(() {
      var mission = _missions[index];
      bool wasRunning = mission['isRunning'] ?? false;
      bool isPriority = mission['isPriority'] ?? false;

      if (!wasRunning) {
        if (isPriority) {
          // Priority Rule: Pause all others
          for (var m in _missions) {
            m['isRunning'] = false;
          }
        }
        mission['isRunning'] = true;
      } else {
        mission['isRunning'] = false;
      }
      DatabaseHelper.saveMissions(_missions);
    });
  }

  // --- EDIT DIALOG ---
  void _showEditMissionDialog(BuildContext context, int index) {
    final mission = _missions[index];
    final TextEditingController titleCtrl =
        TextEditingController(text: mission['title']);
    int duration = mission['totalSeconds'];
    bool isPriority = mission['isPriority'] ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHighest,
            title: const Text("Edit Protocol",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Objective Name...",
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16, color: colorScheme.primary),
                      label: Text(formatDuration(duration)),
                      backgroundColor: colorScheme.primaryContainer,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => TimePickerSheet(
                              onTimeSet: (s) =>
                                  setStateDialog(() => duration = s)),
                        );
                      },
                    ),
                    FilterChip(
                      label: const Text("Priority"),
                      selected: isPriority,
                      selectedColor: Colors.amber.withOpacity(0.2),
                      checkmarkColor: Colors.amber,
                      labelStyle: TextStyle(
                          color: isPriority ? Colors.amber : null,
                          fontWeight:
                              isPriority ? FontWeight.bold : FontWeight.normal),
                      onSelected: (val) =>
                          setStateDialog(() => isPriority = val),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && duration > 0) {
                    setState(() {
                      if (duration != mission['totalSeconds']) {
                        _missions[index]['totalSeconds'] = duration;
                        _missions[index]['remainingSeconds'] = duration;
                        _missions[index]['isRunning'] = false;
                      }
                      _missions[index]['title'] = titleCtrl.text;
                      _missions[index]['isPriority'] = isPriority;

                      DatabaseHelper.saveMissions(_missions);
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Update"),
              ),
            ],
          );
        });
      },
    );
  }

  // --- ADD DIALOG ---
  void _showAddMissionDialog(BuildContext context) {
    final TextEditingController titleCtrl = TextEditingController();
    int duration = 0;
    bool isPriority = false;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHighest,
            title: const Text("New Objective",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Objective Name...",
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16,
                          color: duration > 0 ? colorScheme.primary : null),
                      label: Text(duration > 0
                          ? formatDuration(duration)
                          : "Set Timer"),
                      backgroundColor:
                          duration > 0 ? colorScheme.primaryContainer : null,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => TimePickerSheet(
                              onTimeSet: (s) =>
                                  setStateDialog(() => duration = s)),
                        );
                      },
                    ),
                    FilterChip(
                      label: const Text("Priority"),
                      selected: isPriority,
                      selectedColor: Colors.amber.withOpacity(0.2),
                      checkmarkColor: Colors.amber,
                      labelStyle: TextStyle(
                          color: isPriority ? Colors.amber : null,
                          fontWeight:
                              isPriority ? FontWeight.bold : FontWeight.normal),
                      onSelected: (val) =>
                          setStateDialog(() => isPriority = val),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && duration > 0) {
                    setState(() {
                      _missions.add({
                        'id': DateTime.now().toString(),
                        'title': titleCtrl.text,
                        'totalSeconds': duration,
                        'remainingSeconds': duration,
                        'isRunning': false,
                        'isPriority': isPriority,
                        'isCompleted': false,
                      });
                      DatabaseHelper.saveMissions(_missions);
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Deploy"),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Active Missions",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMissionDialog(context),
        label: const Text("NEW OBJECTIVE",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        icon: const Icon(Icons.add_location_alt),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 100),
          constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.7),
          alignment: Alignment.center,
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: _missions.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> m = entry.value;
              bool isPriority = m['isPriority'] ?? false;
              bool isRunning = m['isRunning'] ?? false;
              double orbSize = isPriority ? 200.0 : 150.0;

              return SizedBox(
                key: ValueKey(m['id']),
                width: orbSize,
                height: orbSize,
                child: _MissionOrb(
                  title: m['title'] ?? "Mission",
                  totalSeconds: m['totalSeconds'] ?? 1,
                  remainingSeconds: m['remainingSeconds'] ?? 0,
                  isRunning: isRunning,
                  isPriority: isPriority,
                  isCompleted: m['isCompleted'] ?? false,
                  colorScheme: Theme.of(context).colorScheme,
                  onTap: () => _toggleMissionState(index),
                  onEdit: () => _showEditMissionDialog(context, index),
                  onDelete: () {
                    setState(() {
                      _missions.removeAt(index);
                      DatabaseHelper.saveMissions(_missions);
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// --- THE ORB WIDGET ---
class _MissionOrb extends StatefulWidget {
  final String title;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isPriority;
  final bool isCompleted;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MissionOrb({
    required this.title,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.isPriority,
    required this.isCompleted,
    required this.colorScheme,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_MissionOrb> createState() => _MissionOrbState();
}

class _MissionOrbState extends State<_MissionOrb>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _morphCtrl;
  late Animation<double> _morphAnimation;
  late AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _waveCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    _morphCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _morphAnimation =
        CurvedAnimation(parent: _morphCtrl, curve: Curves.easeOutBack);

    _progressCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _updateProgress(animate: false);

    if (widget.isRunning) {
      _morphCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_MissionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _morphCtrl.forward();
      } else {
        _morphCtrl.animateBack(0.0, curve: Curves.easeIn);
      }
    }

    if (widget.remainingSeconds != oldWidget.remainingSeconds ||
        widget.totalSeconds != oldWidget.totalSeconds) {
      _updateProgress(animate: widget.isRunning);
    }
  }

  void _updateProgress({required bool animate}) {
    double target = widget.totalSeconds > 0
        ? widget.remainingSeconds / widget.totalSeconds
        : 0.0;
    target = target.clamp(0.0, 1.0);

    if (animate) {
      _progressCtrl.animateTo(target,
          duration: const Duration(seconds: 1), curve: Curves.linear);
    } else {
      _progressCtrl.value = target;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _morphCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;

    Color headColor = widget.isPriority ? Colors.amber : colorScheme.primary;
    Color tailColor =
        widget.isPriority ? Colors.amber.shade200 : colorScheme.secondary;
    if (widget.isCompleted) {
      headColor = Colors.green;
      tailColor = Colors.green.shade200;
    }

    return GestureDetector(
      onTap: widget.onTap,
      // RIGHT CLICK (Desktop)
      onSecondaryTapUp: (d) {
        showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
                d.globalPosition.dx, d.globalPosition.dy, 0, 0),
            items: [
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text("Edit Protocol"),
                    contentPadding: EdgeInsets.zero,
                  )),
              const PopupMenuItem(
                  value: 'del',
                  child: ListTile(
                    leading:
                        Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    title: Text("Abort Mission",
                        style: TextStyle(color: Colors.redAccent)),
                    contentPadding: EdgeInsets.zero,
                  )),
            ]).then((v) {
          if (v == 'del') widget.onDelete();
          if (v == 'edit') widget.onEdit();
        });
      },
      // LONG PRESS (Mobile)
      onLongPress: () {
        showMenu(
            context: context,
            position: const RelativeRect.fromLTRB(
                100, 100, 100, 100), // Simple center positioning fallback
            items: [
              const PopupMenuItem(value: 'edit', child: Text("Edit Protocol")),
              const PopupMenuItem(
                  value: 'del',
                  child: Text("Abort Mission",
                      style: TextStyle(color: Colors.redAccent))),
            ]).then((v) {
          if (v == 'del') widget.onDelete();
          if (v == 'edit') widget.onEdit();
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_pulseCtrl, _waveCtrl, _morphCtrl, _progressCtrl]),
        builder: (context, child) {
          double rawMorph = _morphAnimation.value;
          double clampedMorph = rawMorph.clamp(0.0, 1.0);

          double targetAmp = widget.isPriority ? 6.0 : 4.0;
          double currentAmp = ui.lerpDouble(0.0, targetAmp, rawMorph)!;

          double targetStroke = widget.isPriority ? 4.0 : 3.0;
          double currentStroke = ui.lerpDouble(6.0, targetStroke, rawMorph)!;

          double scale = 1.0 + (_pulseCtrl.value * 0.03 * rawMorph);
          // Only animate phase if running
          double wavePhase =
              widget.isRunning ? _waveCtrl.value * 2 * math.pi : 0;
          double smoothProgress = _progressCtrl.value;

          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: widget.isPriority
                    ? [
                        const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 2))
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // RENDERER
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _MaterialExpressivePainter(
                        headColor: headColor,
                        tailColor: tailColor,
                        trackColor: colorScheme.outline.withOpacity(0.15),
                        progress: smoothProgress,
                        wavePhase: wavePhase,
                        amplitude: currentAmp,
                        strokeWidth: currentStroke,
                        frequency: widget.isPriority ? 24 : 16,
                        morphValue: clampedMorph,
                      ),
                    ),
                  ),

                  // TEXT CONTENT
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0),
                        child: Text(
                          widget.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: widget.isPriority ? 18 : 14,
                            color: widget.isCompleted
                                ? colorScheme.onSurfaceVariant.withOpacity(0.5)
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isCompleted
                            ? "COMPLETE"
                            : formatDuration(widget.remainingSeconds),
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: widget.isPriority ? 14 : 12,
                          color: headColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MaterialExpressivePainter extends CustomPainter {
  final Color headColor;
  final Color tailColor;
  final Color trackColor;
  final double progress;
  final double wavePhase;
  final double amplitude;
  final double strokeWidth;
  final int frequency;
  final double morphValue;

  _MaterialExpressivePainter({
    required this.headColor,
    required this.tailColor,
    required this.trackColor,
    required this.progress,
    required this.wavePhase,
    required this.amplitude,
    required this.strokeWidth,
    required this.frequency,
    required this.morphValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. BACKGROUND TRACK
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double radius = (size.width / 2) - 12;
    final Offset center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // 2. MAIN PAINT
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Gradient gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: (2 * math.pi) - (math.pi / 2),
      tileMode: TileMode.repeated,
      colors: [
        tailColor,
        headColor,
      ],
      stops: const [0.0, 1.0],
    );

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    int totalPoints = 720;
    int drawPoints = (totalPoints * progress).toInt();

    for (int i = 0; i <= drawPoints; i++) {
      double angle = (i / totalPoints) * 2 * math.pi - (math.pi / 2);

      double waveOffset = amplitude *
          math.sin((frequency * (i / totalPoints) * 2 * math.pi) + wavePhase);
      double currentRadius = radius + waveOffset;

      double x = center.dx + currentRadius * math.cos(angle);
      double y = center.dy + currentRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 3. TIP DOT
    if (drawPoints > 0 && morphValue > 0.1) {
      double endAngle =
          (drawPoints / totalPoints) * 2 * math.pi - (math.pi / 2);
      double endWaveOffset = amplitude *
          math.sin((frequency * (drawPoints / totalPoints) * 2 * math.pi) +
              wavePhase);
      double endRadius = radius + endWaveOffset;

      double tipX = center.dx + endRadius * math.cos(endAngle);
      double tipY = center.dy + endRadius * math.sin(endAngle);

      canvas.drawCircle(
          Offset(tipX, tipY), strokeWidth * 1.5, Paint()..color = headColor);
      canvas.drawCircle(
          Offset(tipX, tipY), strokeWidth * 0.7, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MaterialExpressivePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.headColor != headColor;
  }
}

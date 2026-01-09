import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:life_dashboard/database_helper.dart';

// --- HELPER FUNCTION ---
String formatDuration(int totalSeconds) {
  int h = totalSeconds ~/ 3600;
  int m = (totalSeconds % 3600) ~/ 60;
  int s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
      if (m['isRunning'] == true && (m['remainingSeconds'] ?? 0) > 0) {
        m['remainingSeconds']--;
        if (m['remainingSeconds'] <= 0) {
          m['remainingSeconds'] = 0;
          m['isRunning'] = false;
          m['isCompleted'] = true;
          int durationMins = (m['totalSeconds'] ?? 0) ~/ 60;
          if (durationMins < 1) durationMins = 1;
          DatabaseHelper.addFocusMinutes(durationMins);
          DatabaseHelper.incrementMissionsCrushed(1);
        }
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
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

  void _showTimeWheelPicker(
      BuildContext context, int currentSeconds, Function(int) onSet) {
    Duration initial =
        Duration(seconds: currentSeconds > 0 ? currentSeconds : 1800);
    Duration tempDuration = initial;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                color: colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("SET TIMER PROTOCOL",
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    TextButton(
                      onPressed: () {
                        onSet(tempDuration.inSeconds);
                        Navigator.pop(context);
                      },
                      child: Text("CONFIRM",
                          style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace')),
                    )
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                              color: colorScheme.onSurface, fontSize: 18))),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    initialTimerDuration: initial,
                    onTimerDurationChanged: (Duration newDuration) {
                      tempDuration = newDuration;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DIALOGS ---
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
            backgroundColor: colorScheme.surfaceContainer,
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
                    fillColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16,
                          color: duration > 0
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant),
                      label: Text(duration > 0
                          ? formatDuration(duration)
                          : "Set Timer"),
                      backgroundColor:
                          duration > 0 ? colorScheme.primaryContainer : null,
                      onPressed: () {
                        _showTimeWheelPicker(context, duration, (s) {
                          setStateDialog(() => duration = s);
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text("Priority"),
                      selected: isPriority,
                      selectedColor: colorScheme.tertiaryContainer,
                      checkmarkColor: colorScheme.onTertiaryContainer,
                      labelStyle: TextStyle(
                          color: isPriority
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onSurfaceVariant),
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

  // Re-use logic for Edit (Simplified for brevity, similar to Add)
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
            backgroundColor: colorScheme.surfaceContainer,
            title: const Text("Edit Protocol",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    hintText: "Objective Name...",
                    filled: true,
                    fillColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16, color: colorScheme.primary),
                      label: Text(formatDuration(duration)),
                      backgroundColor: colorScheme.primaryContainer,
                      onPressed: () {
                        _showTimeWheelPicker(context, duration, (s) {
                          setStateDialog(() => duration = s);
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text("Priority"),
                      selected: isPriority,
                      selectedColor: colorScheme.tertiaryContainer,
                      checkmarkColor: colorScheme.onTertiaryContainer,
                      labelStyle: TextStyle(
                          color: isPriority
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onSurfaceVariant),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("ACTIVE MISSIONS",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMissionDialog(context),
        label: const Text("NEW OBJECTIVE"),
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
              double orbSize = isPriority ? 200.0 : 160.0;

              return SizedBox(
                key: ValueKey(m['id']),
                width: orbSize,
                height: orbSize,
                child: _ReactiveSphereOrb(
                  title: m['title'] ?? "Mission",
                  totalSeconds: m['totalSeconds'] ?? 1,
                  remainingSeconds: m['remainingSeconds'] ?? 0,
                  isRunning: isRunning,
                  isPriority: isPriority,
                  isCompleted: m['isCompleted'] ?? false,
                  colorScheme: colorScheme, // PASSING THE THEME
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

class _ReactiveSphereOrb extends StatefulWidget {
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

  const _ReactiveSphereOrb({
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
  State<_ReactiveSphereOrb> createState() => _ReactiveSphereOrbState();
}

class _ReactiveSphereOrbState extends State<_ReactiveSphereOrb>
    with TickerProviderStateMixin {
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _velocityX = 0.5;
  double _velocityY = 0.2;

  late AnimationController _physicsCtrl;
  late AnimationController _squigglyCtrl;
  final List<_SpherePoint> _points = [];

  @override
  void initState() {
    super.initState();
    _generateSpherePoints();
    _physicsCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _physicsCtrl.addListener(_updatePhysics);
    _squigglyCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  void _generateSpherePoints() {
    _points.clear();
    const int numPoints = 80;
    const double goldenRatio = (1 + 2.2360679775) / 2;
    for (int i = 0; i < numPoints; i++) {
      double theta = 2 * math.pi * i / goldenRatio;
      double phi = math.acos(1 - 2 * (i + 0.5) / numPoints);
      _points.add(_SpherePoint(math.cos(theta) * math.sin(phi),
          math.sin(theta) * math.sin(phi), math.cos(phi)));
    }
  }

  void _updatePhysics() {
    if (!mounted) return;
    setState(() {
      _rotationX += _velocityX * 0.02;
      _rotationY += _velocityY * 0.02;
      double idleSpeed = widget.isRunning ? 0.05 : 0.01;
      _velocityX = ui.lerpDouble(_velocityX, idleSpeed, 0.05)!;
      _velocityY = ui.lerpDouble(_velocityY, idleSpeed, 0.05)!;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _velocityX += details.delta.dy * 0.01;
      _velocityY -= details.delta.dx * 0.01;
    });
  }

  @override
  void dispose() {
    _physicsCtrl.dispose();
    _squigglyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DYNAMIC COLOR LOGIC
    Color baseColor;
    if (widget.isCompleted) {
      baseColor = widget.colorScheme.secondary; // Muted/Done
    } else if (widget.isPriority) {
      baseColor = widget.colorScheme.tertiary; // Accent/Attention
    } else {
      baseColor = widget.colorScheme.primary; // Standard
    }

    double targetProgress = widget.totalSeconds > 0
        ? widget.remainingSeconds / widget.totalSeconds
        : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onLongPress: widget.onEdit,
      onSecondaryTapUp: (d) => widget.onDelete(),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              baseColor.withOpacity(0.1),
              widget.colorScheme.surface.withOpacity(0.5)
            ],
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. SQUIGGLY BORDER
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: targetProgress, end: targetProgress),
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              builder: (context, smoothProgress, child) {
                return TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: 0.0, end: widget.isRunning ? 4.0 : 0.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, smoothAmplitude, _) {
                      return AnimatedBuilder(
                          animation: _squigglyCtrl,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size.infinite,
                              painter: _SquigglyRingPainter(
                                color: baseColor
                                    .withOpacity(widget.isRunning ? 1.0 : 0.4),
                                phase: _squigglyCtrl.value * 4 * math.pi,
                                amplitude: smoothAmplitude,
                                progress: smoothProgress,
                              ),
                            );
                          });
                    });
              },
            ),

            // 2. 3D SPHERE
            CustomPaint(
              size: Size.infinite,
              painter: _TechSpherePainter(
                points: _points,
                rotationX: _rotationX,
                rotationY: _rotationY,
                color: baseColor,
                isRunning: widget.isRunning,
              ),
            ),

            // 3. TEXT INFO
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: widget.isPriority ? 16 : 13,
                        color: widget.colorScheme.onSurface,
                        shadows: [
                          Shadow(
                              color: widget.colorScheme.surface, blurRadius: 10)
                        ]),
                  ),
                ),
                Text(
                  widget.isCompleted
                      ? "DONE"
                      : formatDuration(widget.remainingSeconds),
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: baseColor,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: widget.colorScheme.surface, blurRadius: 4)
                      ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SquigglyRingPainter extends CustomPainter {
  final Color color;
  final double phase;
  final double amplitude;
  final double progress;

  _SquigglyRingPainter(
      {required this.color,
      required this.phase,
      required this.amplitude,
      required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final Path path = Path();
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 4;
    final double totalAngle = 2 * math.pi * progress;
    final int steps = (180 * progress).toInt().clamp(2, 360);
    const double startAngle = -math.pi / 2;

    for (int i = 0; i <= steps; i++) {
      double percent = i / steps;
      double currentAngle = startAngle + (percent * totalAngle);
      double wobble = math.sin(currentAngle * 18 + phase) * amplitude +
          math.cos(currentAngle * 9 - phase * 1.5) * (amplitude * 0.5);
      double r = radius + wobble;
      double x = center.dx + r * math.cos(currentAngle);
      double y = center.dy + r * math.sin(currentAngle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SquigglyRingPainter old) =>
      old.phase != phase ||
      old.color != color ||
      old.progress != progress ||
      old.amplitude != amplitude;
}

class _SpherePoint {
  double x, y, z;
  _SpherePoint(this.x, this.y, this.z);
}

class _TechSpherePainter extends CustomPainter {
  final List<_SpherePoint> points;
  final double rotationX;
  final double rotationY;
  final Color color;
  final bool isRunning;

  _TechSpherePainter(
      {required this.points,
      required this.rotationX,
      required this.rotationY,
      required this.color,
      required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = (size.width / 2) - 14;
    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (var point in points) {
      double x1 = point.x * math.cos(rotationY) - point.z * math.sin(rotationY);
      double z1 = point.x * math.sin(rotationY) + point.z * math.cos(rotationY);
      double y2 = point.y * math.cos(rotationX) - z1 * math.sin(rotationX);
      double z2 = point.y * math.sin(rotationX) + z1 * math.cos(rotationX);
      double x2 = x1;

      if (z2 < -0.5) continue;
      double depth = (z2 + 2) / 3;
      double px = cx + x2 * radius;
      double py = cy + y2 * radius;

      paint.color =
          color.withOpacity(depth.clamp(0.2, 1.0) * (isRunning ? 1.0 : 0.6));
      double dotSize = isRunning ? 3.0 : 2.0;
      canvas.drawCircle(Offset(px, py), dotSize * depth, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechSpherePainter old) => true;
}

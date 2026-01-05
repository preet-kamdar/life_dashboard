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
    // Global Ticker: Runs every second to update data
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

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                color: Colors.white10,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("SET TIMER PROTOCOL",
                        style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'monospace',
                            fontSize: 12)),
                    TextButton(
                      onPressed: () {
                        onSet(tempDuration.inSeconds);
                        Navigator.pop(context);
                      },
                      child: const Text("CONFIRM",
                          style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace')),
                    )
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle:
                              TextStyle(color: Colors.white, fontSize: 18))),
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
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Edit Protocol",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Objective Name...",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                      selectedColor: Colors.amber.withOpacity(0.2),
                      checkmarkColor: Colors.amber,
                      labelStyle: TextStyle(
                          color: isPriority ? Colors.amber : Colors.white70),
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
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey))),
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
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("New Objective",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Objective Name...",
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.timer,
                          size: 16,
                          color:
                              duration > 0 ? colorScheme.primary : Colors.grey),
                      label: Text(duration > 0
                          ? formatDuration(duration)
                          : "Set Timer"),
                      backgroundColor: duration > 0
                          ? colorScheme.primaryContainer
                          : Colors.white10,
                      onPressed: () {
                        _showTimeWheelPicker(context, duration, (s) {
                          setStateDialog(() => duration = s);
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text("Priority"),
                      selected: isPriority,
                      selectedColor: Colors.amber.withOpacity(0.2),
                      checkmarkColor: Colors.amber,
                      labelStyle: TextStyle(
                          color: isPriority ? Colors.amber : Colors.white70),
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
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey))),
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
  List<_SpherePoint> _points = [];

  @override
  void initState() {
    super.initState();
    _generateSpherePoints();

    // Physics Engine for Sphere
    _physicsCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _physicsCtrl.addListener(_updatePhysics);

    // Wave Engine for Border
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
      double x = math.cos(theta) * math.sin(phi);
      double y = math.sin(theta) * math.sin(phi);
      double z = math.cos(phi);
      _points.add(_SpherePoint(x, y, z));
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
    Color baseColor =
        widget.isPriority ? Colors.amber : widget.colorScheme.primary;
    if (widget.isCompleted) baseColor = Colors.greenAccent;

    // TARGET VALUES
    double targetProgress = widget.totalSeconds > 0
        ? widget.remainingSeconds / widget.totalSeconds
        : 0.0;

    // Logic: If paused, target is full circle (1.0) or current progress?
    // User requested "Static when not activated".
    // We will keep the arc at current progress but FREEZE the amplitude.

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onLongPress: widget.onEdit,
      onSecondaryTapUp: (d) => widget.onDelete(),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [baseColor.withOpacity(0.1), Colors.black.withOpacity(0.8)],
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. REACTIVE SQUIGGLY BORDER
            // Uses TweenAnimationBuilder to smoothly interpolate the countdown (No 1-sec skipping)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: targetProgress, end: targetProgress),
              duration:
                  const Duration(seconds: 1), // Interpolates the 1-second drop
              curve: Curves.linear,
              builder: (context, smoothProgress, child) {
                // Also Animate Amplitude: 0.0 (Static) -> 4.0 (Active)
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
                                    .withOpacity(widget.isRunning ? 1.0 : 0.3),
                                phase: _squigglyCtrl.value * 4 * math.pi,
                                amplitude:
                                    smoothAmplitude, // Controlled by state
                                progress:
                                    smoothProgress, // Controlled by smooth tween
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
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                  ),
                ),
                Text(
                  widget.isCompleted
                      ? "DONE"
                      : formatDuration(widget.remainingSeconds),
                  style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: baseColor,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(color: Colors.black, blurRadius: 2)
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

// --- PAINTERS ---

class _SquigglyRingPainter extends CustomPainter {
  final Color color;
  final double phase;
  final double amplitude;
  final double progress;

  _SquigglyRingPainter({
    required this.color,
    required this.phase,
    required this.amplitude,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If progress is near zero, don't draw
    if (progress <= 0.01) return;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 4;

    // Draw only the remaining arc
    final double totalAngle = 2 * math.pi * progress;
    // Map progress to steps, ensuring we have enough resolution for the wiggle
    final int steps = (180 * progress).toInt().clamp(2, 360);

    // Start from top (-PI/2)
    final double startAngle = -math.pi / 2;

    for (int i = 0; i <= steps; i++) {
      double percent = i / steps;
      double currentAngle = startAngle + (percent * totalAngle);

      // SQUIGGLE MATH:
      // If amplitude is 0 (Static), this resolves to a perfect circle.
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

    // Spark at the tip (only if active)
    if (progress < 0.99 && amplitude > 1.0) {
      double endAngle = startAngle + totalAngle;
      double wobble = math.sin(endAngle * 18 + phase) * amplitude +
          math.cos(endAngle * 9 - phase * 1.5) * (amplitude * 0.5);
      double r = radius + wobble;
      double endX = center.dx + r * math.cos(endAngle);
      double endY = center.dy + r * math.sin(endAngle);

      canvas.drawCircle(Offset(endX, endY), 4.0, Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset(endX, endY), 8.0, Paint()..color = color.withOpacity(0.4));
    }
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

  _TechSpherePainter({
    required this.points,
    required this.rotationX,
    required this.rotationY,
    required this.color,
    required this.isRunning,
  });

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
      double dotSize = isRunning ? 2.5 : 1.8;
      canvas.drawCircle(Offset(px, py), dotSize * depth, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechSpherePainter old) => true;
}

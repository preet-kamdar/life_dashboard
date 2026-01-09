import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:life_dashboard/database_helper.dart';

class ZenScreen extends StatefulWidget {
  const ZenScreen({super.key});

  @override
  State<ZenScreen> createState() => _ZenScreenState();
}

class _ZenScreenState extends State<ZenScreen> with TickerProviderStateMixin {
  bool _isFocusMode = false;
  late Timer _systemTicker;
  late DateTime _now;
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _stopwatchTicker;
  final TextEditingController _bufferController = TextEditingController();

  late AnimationController _physicsController;
  Offset _dvdPos = const Offset(50, 50);
  Offset _dvdVelocity = const Offset(2.0, 2.0);
  final Size _dvdSize = const Size(220, 130);
  Color _dvdColor = Colors.white; // Will be set dynamically

  final List<LiquidDrop> _staticDrops = [];
  final List<LiquidDrop> _fallingDrops = [];
  final Random _rng = Random();

  // We remove the static bitmap background and generate it dynamically in paint

  final double _dashboardTopHeight = 220.0;
  final double _gap = 20.0;
  final double _navBarHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _initRain();

    _systemTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _stopwatchTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_stopwatch.isRunning && mounted) setState(() {});
    });

    _physicsController =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_gameLoop)
          ..forward();
  }

  void _initRain() {
    _staticDrops.clear();
    _fallingDrops.clear();
    for (int i = 0; i < 300; i++) {
      _staticDrops.add(LiquidDrop.randomStatic(_rng));
    }
  }

  void _gameLoop() {
    if (!mounted) return;
    if (_isFocusMode) {
      _updateDvdPhysics();
      if (_rng.nextInt(100) < 5) {
        _fallingDrops.add(LiquidDrop.randomFalling(_rng));
      }
      for (int i = _fallingDrops.length - 1; i >= 0; i--) {
        final drop = _fallingDrops[i];
        drop.velocity += 0.0001;
        drop.y += drop.velocity;
        drop.x += (sin(drop.y * 30 + drop.id) * 0.0002);
        if (drop.y > 1.1) _fallingDrops.removeAt(i);
      }
    }
  }

  void _updateDvdPhysics() {
    final Size screenSize = MediaQuery.of(context).size;
    final double maxX = screenSize.width - _dvdSize.width;
    final double maxY = screenSize.height - _dvdSize.height;

    double nextX = _dvdPos.dx + _dvdVelocity.dx;
    double nextY = _dvdPos.dy + _dvdVelocity.dy;

    if (nextX <= 0 || nextX >= maxX) {
      _dvdVelocity = Offset(-_dvdVelocity.dx, _dvdVelocity.dy);
      nextX = nextX.clamp(0.0, maxX);
      _changeBounceColor();
    }
    if (nextY <= 0 || nextY >= maxY) {
      _dvdVelocity = Offset(_dvdVelocity.dx, -_dvdVelocity.dy);
      nextY = nextY.clamp(0.0, maxY);
      _changeBounceColor();
    }
    setState(() => _dvdPos = Offset(nextX, nextY));
  }

  void _changeBounceColor() {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
    setState(() => _dvdColor = colors[_rng.nextInt(colors.length)]);
  }

  void _onTimerTap() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _isFocusMode = false;
      } else {
        _stopwatch.start();
        _isFocusMode = true;
        _dvdColor =
            Theme.of(context).colorScheme.primary; // Reset color on start
        if (_stopwatch.elapsedMilliseconds < 100) {
          _dvdPos = const Offset(20, 20);
        }
      }
    });
  }

  void _onTimerReset() {
    setState(() {
      _stopwatch.stop();
      _stopwatch.reset();
      _isFocusMode = false;
    });
  }

  String _formatStopwatch() {
    final duration = _stopwatch.elapsed;
    String h = duration.inHours.toString().padLeft(2, "0");
    String m = (duration.inMinutes % 60).toString().padLeft(2, "0");
    String s = (duration.inSeconds % 60).toString().padLeft(2, "0");
    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _systemTicker.cancel();
    _stopwatchTicker.cancel();
    _physicsController.dispose();
    _bufferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseHelper.getSettingsListenable(),
      builder: (context, box, _) {
        final settings = Map<String, dynamic>.from(box.toMap());
        final String renderMode = settings['render_mode'] ?? 'HIGH_PERFORMANCE';
        final bool isHighPerf = renderMode == 'HIGH_PERFORMANCE';

        if (isHighPerf && !_physicsController.isAnimating) {
          _physicsController.repeat();
        } else if (!isHighPerf && _physicsController.isAnimating) {
          _physicsController.stop();
        }

        final Size size = MediaQuery.of(context).size;
        final colorScheme = Theme.of(context).colorScheme;

        // Position Logic
        double timerWidth = (size.width / 2) - 30;
        double timerTop = 20;
        double timerLeft = (size.width / 2) + 10;

        if (_isFocusMode) {
          timerWidth = 340;
          timerTop = (size.height / 2) - 160;
          timerLeft = (size.width / 2) - 170;
        }

        double bufferTop = _dashboardTopHeight + (_gap * 2);
        double bufferLeft = _gap;
        double bufferWidth = size.width - (_gap * 2);
        double bufferHeight = size.height - bufferTop - _navBarHeight - 20;

        if (_isFocusMode) {
          bufferTop = (size.height / 2) + 80;
          bufferHeight = 200;
        }

        return Scaffold(
          backgroundColor: Colors.transparent, // Important!
          body: Stack(
            children: [
              // 1. DYNAMIC BACKGROUND
              Positioned.fill(
                child: CustomPaint(
                  painter: _DynamicBackgroundPainter(colorScheme: colorScheme),
                ),
              ),

              // 2. RAIN & BLUR (High Perf Only)
              if (isHighPerf) ...[
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(seconds: 1),
                    opacity: _isFocusMode ? 1.0 : 0.0,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(color: Colors.black.withOpacity(0.2)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(seconds: 2),
                    opacity: _isFocusMode ? 1.0 : 0.0,
                    child: CustomPaint(
                      painter: RealisticRainPainter(
                        staticDrops: _staticDrops,
                        fallingDrops: _fallingDrops,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                ),
              ],

              // 3. CLOCK CARD (Left Top)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                top: _isFocusMode ? -300 : 20,
                left: 20,
                width: (size.width / 2) - 30,
                height: 220,
                child: _buildClockCard(colorScheme, isFloating: false),
              ),

              // 4. RAM BUFFER (Bottom Area)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                top: bufferTop,
                left: bufferLeft,
                width: bufferWidth,
                height: bufferHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.terminal,
                                  size: 16, color: colorScheme.tertiary),
                              const SizedBox(width: 10),
                              Text("RAM BUFFER // TEMP STORAGE",
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.tertiary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TextField(
                              controller: _bufferController,
                              expands: true,
                              maxLines: null,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface,
                                  fontSize: 14),
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "> Type temporary thoughts here...",
                                  hintStyle: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.3))),
                              cursorColor: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. BOUNCING CLOCK (DVD)
              if (_isFocusMode && isHighPerf)
                Positioned(
                  left: _dvdPos.dx,
                  top: _dvdPos.dy,
                  child: SizedBox(
                    width: _dvdSize.width,
                    height: _dvdSize.height,
                    child: _buildClockCard(colorScheme,
                        isFloating: true, overrideColor: _dvdColor),
                  ),
                ),

              // 6. MAIN STOPWATCH CONTROLLER
              AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                top: timerTop,
                left: timerLeft,
                width: timerWidth,
                height: 220,
                child: GestureDetector(
                  onTap: _onTimerTap,
                  onDoubleTap: _onTimerReset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: _isFocusMode
                          ? colorScheme.surface // Solid when focused
                          : colorScheme.surfaceContainerHighest
                              .withOpacity(0.5), // Translucent when idle
                      border: Border.all(
                          color: _stopwatch.isRunning
                              ? colorScheme.error
                              : Colors.transparent,
                          width: 2),
                      boxShadow:
                          (_isFocusMode && isHighPerf && _stopwatch.isRunning)
                              ? [
                                  BoxShadow(
                                      color: colorScheme.error.withOpacity(0.3),
                                      blurRadius: 40)
                                ]
                              : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_stopwatch.isRunning ? "FOCUS ACTIVE" : "PAUSED",
                            style: TextStyle(
                                fontFamily: 'monospace',
                                color: _stopwatch.isRunning
                                    ? colorScheme.error
                                    : colorScheme.outline,
                                fontSize: 10,
                                letterSpacing: 2)),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatStopwatch(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 80,
                                fontWeight: FontWeight.bold,
                                color: _stopwatch.isRunning
                                    ? colorScheme.error
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _isFocusMode
                              ? "TAP: PAUSE"
                              : "TAP: RESUME // DBL-TAP: RESET",
                          style: TextStyle(
                              fontFamily: 'monospace',
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClockCard(ColorScheme colorScheme,
      {required bool isFloating, Color? overrideColor}) {
    final textColor = overrideColor ?? colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          border:
              Border.all(color: textColor.withOpacity(isFloating ? 0.8 : 0.3)),
          borderRadius: BorderRadius.circular(24),
          color: isFloating
              ? colorScheme.surface.withOpacity(0.9)
              : colorScheme.surfaceContainerLow.withOpacity(0.5),
          boxShadow: isFloating
              ? [BoxShadow(color: textColor.withOpacity(0.3), blurRadius: 20)]
              : []),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("SYS.TIME",
              style: TextStyle(
                  fontFamily: 'monospace',
                  color: textColor.withOpacity(0.5),
                  fontSize: 10)),
          const SizedBox(height: 5),
          FittedBox(
              child: Text(DateFormat('HH:mm').format(_now),
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: textColor))),
        ],
      ),
    );
  }
}

// --- PAINTERS ---

class _DynamicBackgroundPainter extends CustomPainter {
  final ColorScheme colorScheme;
  _DynamicBackgroundPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    // Draws a subtle gradient based on the theme
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.surface,
          colorScheme.surfaceContainer,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _DynamicBackgroundPainter old) =>
      old.colorScheme != colorScheme;
}

class LiquidDrop {
  double x, y, radius, velocity, id, wobble;
  bool isFalling;
  LiquidDrop(
      {required this.x,
      required this.y,
      required this.radius,
      this.velocity = 0,
      this.isFalling = false,
      this.wobble = 0})
      : id = Random().nextDouble() * 100;
  static LiquidDrop randomStatic(Random rng) => LiquidDrop(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 3.0 + rng.nextDouble() * 5.0,
      wobble: rng.nextDouble() * pi * 2);
  static LiquidDrop randomFalling(Random rng) => LiquidDrop(
      x: rng.nextDouble(),
      y: -0.05,
      radius: 5.0 + rng.nextDouble() * 4.0,
      velocity: 0.003 + rng.nextDouble() * 0.002,
      isFalling: true,
      wobble: rng.nextDouble() * pi * 2);
}

class RealisticRainPainter extends CustomPainter {
  final List<LiquidDrop> staticDrops;
  final List<LiquidDrop> fallingDrops;
  final ColorScheme colorScheme;

  RealisticRainPainter(
      {required this.staticDrops,
      required this.fallingDrops,
      required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    // Raindrops now tint with Primary color instead of being just dark/glass
    final Color dropColor = colorScheme.primary.withOpacity(0.1);
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = dropColor;
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = colorScheme.outline.withOpacity(0.1);

    for (var drop in [...staticDrops, ...fallingDrops]) {
      final cx = drop.x * size.width;
      final cy = drop.y * size.height;
      Path path = Path();

      if (drop.isFalling) {
        // Teardrop shape
        path.moveTo(cx, cy - drop.radius * 3.0);
        path.quadraticBezierTo(
            cx + drop.radius, cy + drop.radius, cx, cy + drop.radius);
        path.quadraticBezierTo(
            cx - drop.radius, cy + drop.radius, cx, cy - drop.radius * 3.0);
        path.close();
      } else {
        // Hemispherical static drop
        path.addOval(
            Rect.fromCircle(center: Offset(cx, cy), radius: drop.radius));
      }
      canvas.drawPath(path, paint);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticRainPainter old) => true;
}

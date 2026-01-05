import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:intl/intl.dart'; // <--- ADDED THIS IMPORT TO FIX THE ERROR
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
  Color _dvdColor = Colors.cyanAccent;

  final List<LiquidDrop> _staticDrops = [];
  final List<LiquidDrop> _fallingDrops = [];
  final Random _rng = Random();
  ui.Image? _backgroundImage;

  final double _dashboardTopHeight = 220.0;
  final double _gap = 20.0;
  final double _navBarHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadBackground();
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

  Future<void> _loadBackground() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 2000));
    final paint = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(const Rect.fromLTWH(0, 0, 1000, 2000));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1000, 2000), paint);
    final pic = recorder.endRecording();
    final img = await pic.toImage(1000, 2000);
    setState(() => _backgroundImage = img);
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
    const colors = [
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.redAccent
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
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              if (_backgroundImage != null)
                Positioned.fill(
                    child:
                        CustomPaint(painter: ImagePainter(_backgroundImage!))),
              if (isHighPerf) ...[
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(seconds: 1),
                    opacity: _isFocusMode ? 1.0 : 0.0,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(color: Colors.black.withOpacity(0.4)),
                    ),
                  ),
                ),
                if (_backgroundImage != null)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(seconds: 2),
                      opacity: _isFocusMode ? 1.0 : 0.0,
                      child: CustomPaint(
                        painter: RealisticRainPainter(
                          staticDrops: _staticDrops,
                          fallingDrops: _fallingDrops,
                          background: _backgroundImage!,
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                if (_isFocusMode)
                  Positioned.fill(
                      child: Container(color: Colors.black.withOpacity(0.8))),
              ],
              AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                top: _isFocusMode ? -300 : 20,
                left: 20,
                width: (size.width / 2) - 30,
                height: 220,
                child: _buildClockCard(colorScheme, isFloating: false),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                top: bufferTop,
                left: bufferLeft,
                width: bufferWidth,
                height: bufferHeight,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border(
                        left:
                            BorderSide(color: colorScheme.tertiary, width: 4)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.terminal,
                              size: 20, color: colorScheme.tertiary),
                          const SizedBox(width: 10),
                          Text("RAM BUFFER // TEMP STORAGE",
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: colorScheme.tertiary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TextField(
                          controller: _bufferController,
                          expands: true,
                          maxLines: null,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white,
                              fontSize: 14),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "> Type temporary thoughts here...",
                              hintStyle: TextStyle(color: Colors.white12)),
                          cursorColor: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                      border: Border.all(
                          color: _stopwatch.isRunning
                              ? Colors.redAccent
                              : colorScheme.outline.withOpacity(0.5),
                          width: _isFocusMode ? 2 : 1),
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withOpacity(_isFocusMode ? 0.9 : 0.4),
                      boxShadow: (_isFocusMode && isHighPerf)
                          ? [
                              BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5)
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
                                    ? Colors.redAccent
                                    : Colors.grey,
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
                                    ? Colors.redAccent
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _isFocusMode
                              ? "TAP: PAUSE"
                              : "TAP: RESUME // DBL-TAP: RESET",
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white24,
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
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(isFloating ? 0.6 : 0.3),
      ),
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

class ImagePainter extends CustomPainter {
  final ui.Image image;
  ImagePainter(this.image);
  @override
  void paint(Canvas canvas, Size size) => paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover);
  @override
  bool shouldRepaint(covariant ImagePainter old) => false;
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
  final ui.Image background;
  RealisticRainPainter(
      {required this.staticDrops,
      required this.fallingDrops,
      required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / background.width;
    final double scaleY = size.height / background.height;
    final double baseScale = max(scaleX, scaleY);
    final matrix = Matrix4.identity()
      ..scale(baseScale * 2.5, -baseScale * 2.5)
      ..translate(-100.0, -500.0);
    final lensPaint = Paint()
      ..shader = ImageShader(
          background, TileMode.mirror, TileMode.mirror, matrix.storage)
      ..colorFilter = const ColorFilter.mode(Colors.black38, BlendMode.dstATop);
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withOpacity(0.6);

    for (var drop in [...staticDrops, ...fallingDrops]) {
      final cx = drop.x * size.width;
      final cy = drop.y * size.height;
      Path path = Path();
      if (drop.isFalling) {
        path.moveTo(cx, cy - drop.radius * 3.0);
        path.quadraticBezierTo(
            cx + drop.radius, cy + drop.radius, cx, cy + drop.radius);
        path.quadraticBezierTo(
            cx - drop.radius, cy + drop.radius, cx, cy - drop.radius * 3.0);
        path.close();
      } else {
        path.moveTo(cx, cy - drop.radius * 0.8);
        path.quadraticBezierTo(cx + drop.radius, cy, cx, cy + drop.radius);
        path.quadraticBezierTo(
            cx - drop.radius, cy, cx, cy - drop.radius * 0.8);
        path.close();
      }
      canvas.drawPath(path, lensPaint);
      canvas.drawPath(path, shadowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticRainPainter old) => true;
}

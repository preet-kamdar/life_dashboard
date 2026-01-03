import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class ZenScreen extends StatefulWidget {
  const ZenScreen({super.key});

  @override
  State<ZenScreen> createState() => _ZenScreenState();
}

class _ZenScreenState extends State<ZenScreen> with TickerProviderStateMixin {
  // --- STATE ---
  bool _isFocusMode = false;

  // --- LAYOUT ---
  final double _dashboardTopHeight = 220.0;
  final double _gap = 20.0;
  final double _navBarHeight = 80.0;

  // --- TIMERS ---
  late Timer _systemTicker;
  late DateTime _now;
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _stopwatchTicker;
  final TextEditingController _bufferController = TextEditingController();

  // --- PHYSICS (DVD CLOCK) ---
  late AnimationController _physicsController;
  Offset _dvdPos = const Offset(50, 50);
  Offset _dvdVelocity = const Offset(2.0, 2.0);
  final Size _dvdSize = const Size(220, 130); // Reverted Clock to normal size
  Color _dvdColor = Colors.cyanAccent;

  // --- REALISTIC RAIN ENGINE ---
  final List<LiquidDrop> _staticDrops = [];
  final List<LiquidDrop> _fallingDrops = [];
  final Random _rng = Random();
  ui.Image? _backgroundImage;

  final List<String> _backgrounds = [
    "assets/images/bg_1.jpg",
    "assets/images/bg_2.jpg",
    "assets/images/bg_3.jpg",
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _loadRandomBackground();
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

  Future<void> _loadRandomBackground() async {
    try {
      final String path = _backgrounds.isNotEmpty
          ? _backgrounds[_rng.nextInt(_backgrounds.length)]
          : "";
      if (path.isEmpty) {
        _generateFallbackBackground();
        return;
      }

      final ByteData data = await rootBundle.load(path);
      final List<int> bytes = data.buffer.asUint8List();
      final ui.Codec codec =
          await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() => _backgroundImage = fi.image);
    } catch (e) {
      debugPrint("Asset Error: $e");
      _generateFallbackBackground();
    }
  }

  Future<void> _generateFallbackBackground() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 2000));
    final paint = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(const Rect.fromLTWH(0, 0, 1000, 2000));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1000, 2000), paint);

    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    p.color = Colors.blue.withOpacity(0.1);
    canvas.drawCircle(const Offset(300, 500), 200, p);
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
      if (_rng.nextInt(100) < 5) {
        _fallingDrops.add(LiquidDrop.randomFalling(_rng));
      }

      for (int i = _fallingDrops.length - 1; i >= 0; i--) {
        final drop = _fallingDrops[i];

        drop.velocity += 0.0001;
        drop.y += drop.velocity;
        drop.x += (sin(drop.y * 30 + drop.id) * 0.0002);

        if (_rng.nextInt(100) < 20) {
          _staticDrops.add(LiquidDrop(
            x: drop.x,
            y: drop.y - 0.02,
            radius: drop.radius * (0.2 + _rng.nextDouble() * 0.3),
            isFalling: false,
            wobble: _rng.nextDouble() * pi * 2,
          ));
        }

        if (drop.y > 1.1) {
          _fallingDrops.removeAt(i);
        }
      }

      if (_staticDrops.length > 700) {
        _staticDrops.removeRange(0, 50);
      }
    }

    if (_isFocusMode) {
      _updateDvdPhysics();
    }
  }

  void _updateDvdPhysics() {
    final Size screenSize = MediaQuery.of(context).size;
    final double maxX = screenSize.width - _dvdSize.width;
    final double maxY = screenSize.height - _dvdSize.height - _navBarHeight;

    final Rect timerRect = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 300,
        height: 200);

    double nextX = _dvdPos.dx + _dvdVelocity.dx;
    double nextY = _dvdPos.dy + _dvdVelocity.dy;
    final Rect dvdRect =
        Rect.fromLTWH(nextX, nextY, _dvdSize.width, _dvdSize.height);
    bool bounced = false;

    if (nextX <= 0 || nextX >= maxX) {
      _dvdVelocity = Offset(-_dvdVelocity.dx, _dvdVelocity.dy);
      nextX = nextX.clamp(0.0, maxX);
      bounced = true;
    }
    if (nextY <= 0 || nextY >= maxY) {
      _dvdVelocity = Offset(_dvdVelocity.dx, -_dvdVelocity.dy);
      nextY = nextY.clamp(0.0, maxY);
      bounced = true;
    }

    if (dvdRect.overlaps(timerRect)) {
      Rect intersect = dvdRect.intersect(timerRect);
      if (intersect.width < intersect.height) {
        _dvdVelocity = Offset(-_dvdVelocity.dx, _dvdVelocity.dy);
        nextX = _dvdVelocity.dx < 0
            ? timerRect.left - _dvdSize.width - 1
            : timerRect.right + 1;
      } else {
        _dvdVelocity = Offset(_dvdVelocity.dx, -_dvdVelocity.dy);
        nextY = _dvdVelocity.dy < 0
            ? timerRect.top - _dvdSize.height - 1
            : timerRect.bottom + 1;
      }
      bounced = true;
    }

    if (bounced) _changeBounceColor();
    setState(() => _dvdPos = Offset(nextX, nextY));
  }

  void _changeBounceColor() {
    const colors = [
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.amberAccent
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

  String _getKatakanaDate() {
    const days = ["マンデー", "チューズデー", "ウェンズデー", "サーズデー", "フライデー", "サタデー", "サンデー"];
    const months = [
      "",
      "ジャニュアリー",
      "フェブラリー",
      "マーチ",
      "エイプリル",
      "メイ",
      "ジューン",
      "ジュライ",
      "オーガスト",
      "セプテンバー",
      "オクトーバー",
      "ノーベンバー",
      "ディセンバー"
    ];
    String dayName = days[_now.weekday - 1];
    String monthName = months[_now.month];
    return "$monthName ${_now.day} // $dayName";
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
    final Size size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    const duration = Duration(milliseconds: 1000);
    const curve = Curves.easeInOutCubic;

    // DEFAULT SIZES (When not in focus)
    double timerWidth = (size.width / 2) - (_gap * 1.5);
    double timerHeight = _dashboardTopHeight;
    double timerTop = _gap;
    double timerLeft = (size.width / 2) + (_gap / 2);

    // FOCUS MODE SIZES (THE SUPERSIZED UPDATE)
    if (_isFocusMode) {
      timerWidth = 340; // Wider
      timerHeight = 220; // Taller
      timerTop = (size.height / 2) - 110; // Centered vertically
      timerLeft = (size.width / 2) - 170; // Centered horizontally
    }

    double bufferTop = _dashboardTopHeight + (_gap * 2);
    double bufferLeft = _gap;
    double bufferWidth = size.width - (_gap * 2);
    double bufferHeight = size.height - bufferTop - _navBarHeight - 20;

    if (_isFocusMode) bufferTop = size.height + 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 0. BG
          if (_backgroundImage != null)
            Positioned.fill(
                child: CustomPaint(painter: ImagePainter(_backgroundImage!))),

          // 1. BLUR
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

          // 2. REALISTIC RAIN
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

          // DASHBOARD CLOCK
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            top: _isFocusMode ? -300 : _gap,
            left: _gap,
            width: (size.width / 2) - (_gap * 1.5),
            height: _dashboardTopHeight,
            child: _buildClockCard(colorScheme, isFloating: false),
          ),

          // FLOATING CLOCK (Original Size)
          if (_isFocusMode)
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

          // BUFFER
          AnimatedPositioned(
            duration: duration,
            curve: curve,
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
                    left: BorderSide(color: colorScheme.tertiary, width: 4)),
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
                      Text("RAM BUFFER",
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
                          fontSize: 16),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "> Input stream...",
                          hintStyle: TextStyle(color: Colors.white12)),
                      cursorColor: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TIMER
          AnimatedPositioned(
            duration: duration,
            curve: curve,
            top: timerTop,
            left: timerLeft,
            width: timerWidth,
            height: timerHeight,
            child: GestureDetector(
              onTap: _onTimerTap,
              onDoubleTap: _onTimerReset,
              child: AnimatedContainer(
                duration: duration,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _stopwatch.isRunning
                          ? Colors.redAccent
                          : colorScheme.secondary.withOpacity(0.5),
                      width: _isFocusMode ? 2 : 1),
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(_isFocusMode ? 0.9 : 0.3),
                  boxShadow: _isFocusMode
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
                          // UPDATED FONT SIZE: 90 for massive visibility
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 90,
                              fontWeight: FontWeight.bold,
                              color: _stopwatch.isRunning
                                  ? Colors.redAccent
                                  : colorScheme.secondary,
                              shadows: _stopwatch.isRunning
                                  ? [
                                      const Shadow(
                                          color: Colors.redAccent,
                                          blurRadius: 15)
                                    ]
                                  : []),
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
        boxShadow: isFloating
            ? [BoxShadow(color: textColor.withOpacity(0.3), blurRadius: 15)]
            : [],
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
          if (!isFloating) ...[
            const SizedBox(height: 5),
            FittedBox(
                child: Text(_getKatakanaDate(),
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white38,
                        fontSize: 10))),
          ]
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
  double x;
  double y;
  double radius;
  double velocity;
  double id;
  double wobble;
  bool isFalling;

  LiquidDrop({
    required this.x,
    required this.y,
    required this.radius,
    this.velocity = 0,
    this.isFalling = false,
    this.wobble = 0,
  }) : id = Random().nextDouble() * 100;

  static LiquidDrop randomStatic(Random rng) {
    return LiquidDrop(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 3.0 + rng.nextDouble() * 5.0,
      wobble: rng.nextDouble() * pi * 2,
    );
  }

  static LiquidDrop randomFalling(Random rng) {
    return LiquidDrop(
      x: rng.nextDouble(),
      y: -0.05,
      radius: 5.0 + rng.nextDouble() * 4.0,
      velocity: 0.003 + rng.nextDouble() * 0.002,
      isFalling: true,
      wobble: rng.nextDouble() * pi * 2,
    );
  }
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

    final shinePaint = Paint()..color = Colors.white.withOpacity(0.60);
    final glossPaint = Paint()..color = Colors.white.withOpacity(0.2);

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withOpacity(0.6);

    final allDrops = [...staticDrops, ...fallingDrops];

    for (var drop in allDrops) {
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
      canvas.drawCircle(Offset(cx - drop.radius * 0.2, cy - drop.radius * 0.2),
          drop.radius * 0.2, shinePaint);
      canvas.drawCircle(Offset(cx + drop.radius * 0.2, cy + drop.radius * 0.3),
          drop.radius * 0.1, glossPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticRainPainter old) => true;
}

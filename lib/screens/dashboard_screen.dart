import 'dart:io';
import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // REQUIRED
import 'package:life_dashboard/screens/mission_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TimelineItem> _timeline = [];
  List<Map<String, dynamic>> _gallery = []; // NEW: Gallery Data
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final missions = DatabaseHelper.loadMissions();
    final routines = DatabaseHelper.loadRoutine();
    final journal = DatabaseHelper.loadJournal();
    final sessions = DatabaseHelper.loadSessions();
    final gallery = DatabaseHelper.loadGallery(); // NEW

    List<TimelineItem> items = [];

    // 1. JOURNAL
    for (var j in journal) {
      DateTime dt = DateTime.tryParse(j['date']) ?? DateTime.now();
      items.add(TimelineItem(
        type: TimelineType.journal,
        time: dt,
        title: j['title'],
        subtitle: "Commit ${j['id'].toString().substring(0, 7)}",
        data: j,
      ));
    }

    // 2. ROUTINES
    DateTime routineBaseTime =
        DateTime.now().subtract(const Duration(hours: 4));
    for (var i = 0; i < routines.length; i++) {
      var r = routines[i];
      items.add(TimelineItem(
        type: TimelineType.routine,
        time: routineBaseTime.add(Duration(minutes: i * 30)),
        title: r['title'],
        subtitle: r['isCompleted'] ? "Protocol Complete" : "Pending Action",
        isCompleted: r['isCompleted'],
        data: r,
        index: i,
      ));
    }

    // 3. MISSIONS
    for (var m in missions) {
      items.add(TimelineItem(
        type: TimelineType.mission,
        time: DateTime.now(),
        title: m['title'],
        subtitle: "${m['duration']} min objective",
        data: m,
      ));
    }

    // 4. VENT SESSIONS
    for (var s in sessions) {
      DateTime dt = DateTime.tryParse(s['date'] ?? '') ?? DateTime.now();
      items.add(TimelineItem(
        type: TimelineType.vent,
        time: dt,
        title: s['topic'] ?? "Neural Session",
        subtitle: "Logged with Sergeant",
        data: s,
      ));
    }

    items.sort((a, b) => b.time.compareTo(a.time));

    if (mounted) {
      setState(() {
        _timeline = items;
        _gallery = gallery;
      });
    }
  }

  // --- NEW: CAMERA LOGIC ---
  Future<void> _captureDailyPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        // Save to DB
        await DatabaseHelper.saveGalleryImage(photo.path, "Daily Log");
        _loadData(); // Refresh UI
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera Error: $e")),
      );
    }
  }

  void _showImagePreview(String path, String date) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(path)),
            ),
            const SizedBox(height: 10),
            Text(date,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _toggleRoutine(int index, bool? value) async {
    final routines = DatabaseHelper.loadRoutine();
    if (index < routines.length) {
      routines[index]['isCompleted'] = value;
      await DatabaseHelper.saveRoutine(routines);
      _loadData();
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final String todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Check if we took a photo today
    bool hasPhotoToday = _gallery.any((img) => img['date'] == todayStr);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. HEADER
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(now).toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: colorScheme.primary,
                  ),
                ),
                Text(DateFormat('MMMM d').format(now)),
              ],
            ),
            centerTitle: false,
            actions: [
              // Quick Camera Button (if not taken today)
              if (!hasPhotoToday)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton.filledTonal(
                    onPressed: _captureDailyPhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    tooltip: "Log Today's Visual",
                  ),
                ),
            ],
          ),

          // 2. VISUAL LOG (PHOTOS STYLE)
          // Only show if there are images
          if (_gallery.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text("VISUAL LOG",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 columns like Photos Month View
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0, // Square crops
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Limit to recent 6 photos on dashboard to keep it clean
                    // Or remove limit to show all. Let's show recent 6.
                    if (index >= 6) return null;
                    if (index >= _gallery.length) return null;

                    final img = _gallery[index];
                    final File file = File(img['path']);

                    return GestureDetector(
                      onTap: () => _showImagePreview(img['path'], img['date']),
                      onLongPress: () async {
                        // Simple delete confirmation
                        await DatabaseHelper.deleteGalleryImage(img['id']);
                        _loadData();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                              12), // Photos Style Rounding
                          image: file.existsSync()
                              ? DecorationImage(
                                  image: FileImage(file), fit: BoxFit.cover)
                              : null,
                        ),
                        child: !file.existsSync()
                            ? const Icon(Icons.broken_image, size: 20)
                            : null,
                      ),
                    );
                  },
                  childCount: _gallery.length > 6 ? 6 : _gallery.length,
                ),
              ),
            ),
          ],

          // 3. TIMELINE HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text("STREAM",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),

          // 4. TIMELINE STREAM
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _timeline[index];
                  return _buildTimelineRow(context, item);
                },
                childCount: _timeline.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(BuildContext context, TimelineItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = DateFormat('HH:mm').format(item.time);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Content Card
          Expanded(
            child: _buildItemCard(context, item),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, TimelineItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    // --- MISSION ---
    if (item.type == TimelineType.mission) {
      return Card(
        color: colorScheme.primaryContainer,
        child: InkWell(
          onTap: () => _navigateTo(const MissionScreen()),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag,
                        size: 16, color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text("ACTIVE MISSION",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer
                                .withOpacity(0.7))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.title,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    // --- ROUTINE ---
    if (item.type == TimelineType.routine) {
      final isDone = item.isCompleted;
      return Card(
        color: isDone
            ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
            : colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: () => _toggleRoutine(item.index!, !isDone),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: TextStyle(
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                              fontWeight: FontWeight.w600)),
                      Text(item.subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Checkbox(
                  value: isDone,
                  onChanged: (v) => _toggleRoutine(item.index!, v),
                  shape: const CircleBorder(),
                  activeColor: colorScheme.primary,
                )
              ],
            ),
          ),
        ),
      );
    }

    // --- JOURNAL ---
    if (item.type == TimelineType.journal) {
      return Card(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side:
                BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.commit, size: 16, color: colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Text(item.subtitle, // Hash
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    // --- VENT SESSION ---
    if (item.type == TimelineType.vent) {
      return Card(
        color: colorScheme.errorContainer.withOpacity(0.3),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.psychology, color: colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NEURAL LOG",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error)),
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurface)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

enum TimelineType { mission, routine, journal, vent }

class TimelineItem {
  final TimelineType type;
  final DateTime time;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final dynamic data;
  final int? index;

  TimelineItem({
    required this.type,
    required this.time,
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.data,
    this.index,
  });
}

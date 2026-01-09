import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart'; // Required for ValueListenable
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static late Box _settingsBox;
  static late Box _missionsBox;
  static late Box _routinesBox;
  static late Box _sessionsBox;
  static late Box _journalBox;
  static late Box _statsBox;
  static late Box _galleryBox;

  static Future<void> init() async {
    // 1. SETUP DESKTOP PATH (Linux/Windows/Mac Support)
    final String currentDir = Directory.current.path;
    final String dbPath = '$currentDir/database_storage';
    final Directory appDir = Directory(dbPath);
    if (!await appDir.exists()) await appDir.create(recursive: true);

    // Initialize Hive at this path
    await Hive.initFlutter(appDir.path);

    // 2. OPEN BOXES
    _settingsBox = await Hive.openBox('settings');
    _missionsBox = await Hive.openBox('missions');
    _routinesBox = await Hive.openBox('routines');
    _sessionsBox = await Hive.openBox('sessions');
    _journalBox = await Hive.openBox('journal');
    _statsBox = await Hive.openBox('stats');
    _galleryBox = await Hive.openBox('gallery');

    // 3. DEFAULTS
    if (_settingsBox.isEmpty) {
      await _settingsBox.putAll({
        'user_name': 'Operator',
        'bot_name': 'Sergeant',
        'ai_url': 'http://localhost:1234/v1/chat/completions',
        'is_dark_mode': true,
        'theme_index': 0,
        'ruthless_mode': true,
      });
    }

    // 4. RUN MAINTENANCE
    await _performMaintenance();
  }

  // --- 1. SETTINGS & LISTENABLES (Fixes main.dart / zen_screen.dart) ---

  static ValueListenable<Box> getSettingsListenable() {
    return _settingsBox.listenable();
  }

  static Map<String, dynamic> getSettings() =>
      Map<String, dynamic>.from(_settingsBox.toMap());
  static Future<void> updateSetting(String k, dynamic v) async =>
      await _settingsBox.put(k, v);

  // --- 2. DATA MANAGEMENT (Fixes settings_screen.dart) ---

  static Future<bool> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data.containsKey('settings')) {
        await _settingsBox.clear();
        await _settingsBox.putAll(data['settings']);
      }
      if (data.containsKey('stats')) {
        await _statsBox.clear();
        await _statsBox.putAll(data['stats']);
      }
      // Note: You can add imports for missions/journal here if needed later
      return true;
    } catch (e) {
      if (kDebugMode) print("Import Error: $e");
      return false;
    }
  }

  static String exportData() => jsonEncode({
        'settings': _settingsBox.toMap(),
        'stats': _statsBox.toMap(),
      });

  static Future<void> wipeData() async {
    await _settingsBox.clear();
    await _missionsBox.clear();
    await _routinesBox.clear();
    await _sessionsBox.clear();
    await _journalBox.clear();
    await _statsBox.clear();
    await _galleryBox.clear();
    await init();
  }

  // --- 3. GALLERY (PIC LOG) LOGIC ---

  static List<Map<String, dynamic>> loadGallery() {
    return _galleryBox.values.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
  }

  static Future<void> saveGalleryImage(String path, String note) async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await _galleryBox.put(id, {
      'id': id,
      'path': path,
      'date': today,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteGalleryImage(String id) async {
    await _galleryBox.delete(id);
  }

  // --- 4. MAINTENANCE & EXISTING LOGIC ---

  static Future<void> _performMaintenance() async {
    final String lastDate = _statsBox.get('last_login_date') ?? '';
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastDate != todayDate) {
      List<Map<String, dynamic>> routines = loadRoutine();
      for (var r in routines) {
        r['isCompleted'] = false;
      }
      await saveRoutine(routines);
      await setLastLoginDate(todayDate);
    }
  }

  // --- MISSIONS ---
  static List<Map<String, dynamic>> loadMissions() {
    final data = _missionsBox.get('current_missions');
    return data == null
        ? []
        : List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveMissions(List<Map<String, dynamic>> m) async =>
      await _missionsBox.put('current_missions', jsonEncode(m));

  // --- ROUTINES ---
  static List<Map<String, dynamic>> loadRoutine() {
    final data = _routinesBox.get('daily_routine');
    return data == null
        ? []
        : List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveRoutine(List<Map<String, dynamic>> r) async =>
      await _routinesBox.put('daily_routine', jsonEncode(r));

  // --- VENT SESSIONS ---
  static List<Map<String, dynamic>> loadSessions() => _sessionsBox.values
      .map((v) => Map<String, dynamic>.from(v))
      .toList()
      .reversed
      .toList();
  static Future<void> saveSession(
          String id, String t, String d, List<Map<String, dynamic>> m) async =>
      await _sessionsBox
          .put(id, {'id': id, 'topic': t, 'date': d, 'messages': m});
  static Future<void> deleteSession(String id) async =>
      await _sessionsBox.delete(id);

  // --- JOURNAL ---
  static List<Map<String, dynamic>> loadJournal() => _journalBox.values
      .map((v) => Map<String, dynamic>.from(v))
      .toList()
      .reversed
      .toList();
  static Future<void> saveJournalEntry(
          String id, String date, String title, String body) async =>
      await _journalBox
          .put(id, {'id': id, 'title': title, 'body': body, 'date': date});
  static Future<void> deleteJournalEntry(String id) async =>
      await _journalBox.delete(id);

  // --- STATS ---
  static int getTotalFocusMinutes() =>
      _statsBox.get('total_focus_minutes', defaultValue: 0);
  static Future<void> addFocusMinutes(int minutes) async {
    int current = getTotalFocusMinutes();
    await _statsBox.put('total_focus_minutes', current + minutes);
  }

  static int getTotalMissionsCrushed() =>
      _statsBox.get('total_missions_crushed', defaultValue: 0);
  static Future<void> incrementMissionsCrushed(int count) async {
    int current = getTotalMissionsCrushed();
    await _statsBox.put('total_missions_crushed', current + count);
  }

  static String getLastLoginDate() => _statsBox.get('last_login_date') ?? '';
  static Future<void> setLastLoginDate(String date) async =>
      await _statsBox.put('last_login_date', date);
}

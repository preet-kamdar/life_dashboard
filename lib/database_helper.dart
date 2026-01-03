import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
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

  static Future<void> init() async {
    final String currentDir = Directory.current.path;
    final String dbPath = '$currentDir/database_storage';
    final Directory appDir = Directory(dbPath);
    if (!await appDir.exists()) await appDir.create(recursive: true);

    Hive.init(appDir.path);

    _settingsBox = await Hive.openBox('settings');
    _missionsBox = await Hive.openBox('missions');
    _routinesBox = await Hive.openBox('routines');
    _sessionsBox = await Hive.openBox('sessions');
    _journalBox = await Hive.openBox('journal');
    _statsBox = await Hive.openBox('stats');

    if (_settingsBox.isEmpty) {
      await _settingsBox.putAll({
        'user_name': 'Preet',
        'bot_name': 'Sergeant',
        'ai_url': 'http://localhost:1234/v1/chat/completions',
        'is_dark_mode': true,
        'theme_index': 0,
        'ruthless_mode': true,
        'render_mode': 'HIGH_PERFORMANCE', // New Default
      });
    }

    await _performMaintenance();
  }

  static ValueListenable<Box> getSettingsListenable() {
    return _settingsBox.listenable();
  }

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

    List<Map<String, dynamic>> missions = loadMissions();
    List<Map<String, dynamic>> activeMissions = [];
    int harvestedMinutes = 0;
    int missionsCompletedCount = 0;

    for (var m in missions) {
      bool timeUp = (m['remainingSeconds'] ?? 0) <= 0;
      bool markedDone = m['isCompleted'] ?? false;

      if (timeUp || markedDone) {
        int duration = 0;
        if (m['duration'] is int) {
          duration = m['duration'];
        } else if (m['duration'] is String) {
          String d = m['duration'];
          duration = int.tryParse(d.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }

        if (markedDone) {
          harvestedMinutes += duration;
          missionsCompletedCount++;
        }
      } else {
        activeMissions.add(m);
      }
    }

    if (activeMissions.length < missions.length) {
      await saveMissions(activeMissions);
      await addFocusMinutes(harvestedMinutes);
      await incrementMissionsCrushed(missionsCompletedCount);
    }
  }

  // --- DATA METHODS ---
  static Map<String, dynamic> getSettings() =>
      Map<String, dynamic>.from(_settingsBox.toMap());
  static Future<void> updateSetting(String k, dynamic v) async =>
      await _settingsBox.put(k, v);

  static List<Map<String, dynamic>> loadMissions() {
    final data = _missionsBox.get('current_missions');
    return data == null
        ? []
        : List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveMissions(List<Map<String, dynamic>> m) async =>
      await _missionsBox.put('current_missions', jsonEncode(m));

  static List<Map<String, dynamic>> loadRoutine() {
    final data = _routinesBox.get('daily_routine');
    return data == null
        ? []
        : List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  static Future<void> saveRoutine(List<Map<String, dynamic>> r) async =>
      await _routinesBox.put('daily_routine', jsonEncode(r));

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

  // --- BACKUP & RESTORE SYSTEM ---

  // Export everything
  static String exportData() => jsonEncode({
        'settings': _settingsBox.toMap(),
        'stats': _statsBox.toMap(),
        'missions': loadMissions(),
        'routines': loadRoutine(),
        'journal': _journalBox.toMap(), // Store as raw map for backup
        'sessions': _sessionsBox.toMap(),
      });

  static Future<bool> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data.containsKey('settings')) {
        await _settingsBox.putAll(data['settings']);
      }
      if (data.containsKey('stats')) await _statsBox.putAll(data['stats']);

      // Complex objects need careful restoration
      if (data.containsKey('missions')) {
        await saveMissions(List<Map<String, dynamic>>.from(data['missions']));
      }
      if (data.containsKey('routines')) {
        await saveRoutine(List<Map<String, dynamic>>.from(data['routines']));
      }
      if (data.containsKey('journal')) {
        await _journalBox.putAll(data['journal']);
      }
      if (data.containsKey('sessions')) {
        await _sessionsBox.putAll(data['sessions']);
      }
      return true;
    } catch (e) {
      print("IMPORT ERROR: $e");
      return false;
    }
  }

  static Future<void> wipeData() async {
    await _settingsBox.clear();
    await _missionsBox.clear();
    await _routinesBox.clear();
    await _sessionsBox.clear();
    await _journalBox.clear();
    await _statsBox.clear();
    await init();
  }
}

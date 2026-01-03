import 'package:hive/hive.dart';
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
    // 1. SETUP DESKTOP PATH (Keep your existing logic)
    final String currentDir = Directory.current.path;
    final String dbPath = '$currentDir/database_storage';
    final Directory appDir = Directory(dbPath);
    if (!await appDir.exists()) await appDir.create(recursive: true);

    Hive.init(appDir.path);

    // 2. OPEN BOXES
    _settingsBox = await Hive.openBox('settings');
    _missionsBox = await Hive.openBox('missions');
    _routinesBox = await Hive.openBox('routines');
    _sessionsBox = await Hive.openBox('sessions');
    _journalBox = await Hive.openBox('journal');
    _statsBox = await Hive.openBox('stats');

    // 3. DEFAULTS
    if (_settingsBox.isEmpty) {
      await _settingsBox.putAll({
        'user_name': 'Preet',
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

  // --- MAINTENANCE: MIDNIGHT RESET & STATS HARVESTER ---
  static Future<void> _performMaintenance() async {
    final String lastDate = _statsBox.get('last_login_date') ?? '';
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // TASK 3: MIDNIGHT ROUTINE RESET
    if (lastDate != todayDate) {
      print(" >>> NEW DAY: Resetting Routines...");
      List<Map<String, dynamic>> routines = loadRoutine();
      for (var r in routines) {
        r['isCompleted'] = false;
      }
      await saveRoutine(routines);
      await setLastLoginDate(todayDate);
    }

    // TASK 4: MISSION GARBAGE COLLECTOR (UPDATED)
    List<Map<String, dynamic>> missions = loadMissions();
    List<Map<String, dynamic>> activeMissions = [];
    int harvestedMinutes = 0;
    int missionsCompletedCount = 0;

    for (var m in missions) {
      bool timeUp = (m['remainingSeconds'] ?? 0) <= 0;
      bool markedDone = m['isCompleted'] ?? false;

      // IF MISSION IS FINISHED:
      if (timeUp || markedDone) {
        // HARVEST DATA BEFORE DELETING
        // We assume 'duration' is the total minutes.
        // If you store it as string "30 min", we parse it.
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
        // We do NOT add it to activeMissions, effectively deleting it.
      } else {
        // KEEP MISSION
        activeMissions.add(m);
      }
    }

    // SAVE UPDATES
    if (activeMissions.length < missions.length) {
      print(
          " >>> CLEANUP: Harvested $harvestedMinutes mins from $missionsCompletedCount missions.");

      // Update Database
      await saveMissions(activeMissions);
      await addFocusMinutes(harvestedMinutes);
      await incrementMissionsCrushed(missionsCompletedCount);
    }
  }

  // --- SETTINGS ---
  static Map<String, dynamic> getSettings() =>
      Map<String, dynamic>.from(_settingsBox.toMap());
  static Future<void> updateSetting(String k, dynamic v) async =>
      await _settingsBox.put(k, v);

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

  // --- STATS (Sector D Logic) ---

  // 1. Total Focus Time (Accumulated forever)
  static int getTotalFocusMinutes() =>
      _statsBox.get('total_focus_minutes', defaultValue: 0);

  static Future<void> addFocusMinutes(int minutes) async {
    int current = getTotalFocusMinutes();
    await _statsBox.put('total_focus_minutes', current + minutes);
  }

  // 2. Total Missions Crushed (Accumulated forever)
  static int getTotalMissionsCrushed() =>
      _statsBox.get('total_missions_crushed', defaultValue: 0);

  static Future<void> incrementMissionsCrushed(int count) async {
    int current = getTotalMissionsCrushed();
    await _statsBox.put('total_missions_crushed', current + count);
  }

  static String getLastLoginDate() => _statsBox.get('last_login_date') ?? '';
  static Future<void> setLastLoginDate(String date) async =>
      await _statsBox.put('last_login_date', date);

  // --- DEBUG TOOLS ---
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
    await init();
  }
}

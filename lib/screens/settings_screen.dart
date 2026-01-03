import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_dashboard/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- STATE ---
  late Map<String, dynamic> _settings;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Color Names for the TUI (Text User Interface)
  final List<String> _colorNames = [
    "INDIGO",
    "ERROR_RED",
    "TERMINAL_GREEN",
    "ORANGE",
    "BLUE",
    "PURPLE",
    "TEAL",
    "BROWN",
    "SLATE",
    "PINK",
    "LIME",
    "AMBER",
    "CYAN",
    "VIOLET",
    "DARK_GREEN",
    "BLOOD_RED"
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _settings = DatabaseHelper.getSettings();
      _urlController.text =
          _settings['ai_url'] ?? 'http://10.0.2.2:11434/v1/chat/completions';
      _usernameController.text = _settings['username'] ?? 'User';
    });
  }

  // --- ACTIONS ---

  void _cycleTheme() {
    int current = _settings['theme_index'] ?? 0;
    int next = (current + 1) % _colorNames.length;
    DatabaseHelper.updateSetting('theme_index', next);
    setState(() => _settings['theme_index'] = next);
  }

  void _toggleRuthless() {
    bool current = _settings['ruthless_mode'] ?? true;
    DatabaseHelper.updateSetting('ruthless_mode', !current);
    setState(() => _settings['ruthless_mode'] = !current);
  }

  void _saveTextSetting(String key, String value) {
    DatabaseHelper.updateSetting(key, value);
    setState(() => _settings[key] = value);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("> SETTING_UPDATED"),
      duration: Duration(milliseconds: 500),
      backgroundColor: Colors.black,
    ));
  }

  Future<void> _factoryReset() async {
    await DatabaseHelper.wipeData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("> SYSTEM_WIPED. REBOOTING...")));
      Navigator.pop(context); // Exit settings
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current Values
    String themeName = _colorNames[_settings['theme_index'] ?? 0];
    bool ruthless = _settings['ruthless_mode'] ?? true;
    Color highlight =
        Colors.greenAccent; // Terminal Green for this screen specifically

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Almost black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: highlight),
        title: Text("/// SYSTEM_CONFIG ///",
            style: TextStyle(
                fontFamily: 'monospace',
                color: highlight,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // HEADER
          _buildComment("# LIFE_OS CONFIGURATION FILE v2.4"),
          _buildComment("# EDIT WITH CAUTION. CHANGES APPLY IMMEDIATELY."),
          const SizedBox(height: 20),

          // --- SECTION: USER PROFILE ---
          _buildSectionHeader("[USER_PROFILE]"),
          _buildConfigRow(
            label: "USER_ID",
            valueWidget: _buildInlineTextField(_usernameController,
                (val) => _saveTextSetting('username', val), highlight),
          ),
          _buildConfigRow(
            label: "ACCESS_LEVEL",
            valueWidget: Text("ADMINISTRATOR",
                style: TextStyle(fontFamily: 'monospace', color: highlight)),
          ),
          const SizedBox(height: 20),

          // --- SECTION: VISUALS ---
          _buildSectionHeader("[VISUAL_SETTINGS]"),
          _buildConfigRow(
            label: "THEME_COLOR",
            valueWidget: _buildTappableValue(themeName, _cycleTheme, highlight),
            comment: "# TAP TO CYCLE",
          ),
          _buildConfigRow(
            label: "RENDER_MODE",
            valueWidget: Text("HIGH_PERFORMANCE",
                style: TextStyle(fontFamily: 'monospace', color: highlight)),
          ),
          const SizedBox(height: 20),

          // --- SECTION: AI CORE ---
          _buildSectionHeader("[AI_CORE]"),
          _buildConfigRow(
            label: "RUTHLESS_MODE",
            valueWidget: _buildTappableValue(ruthless ? "TRUE" : "FALSE",
                _toggleRuthless, ruthless ? Colors.redAccent : highlight),
          ),
          _buildConfigRow(
            label: "ENDPOINT_URL",
            valueWidget: _buildInlineTextField(_urlController,
                (val) => _saveTextSetting('ai_url', val), highlight),
          ),
          const SizedBox(height: 20),

          // --- SECTION: SYSTEM MAINTENANCE ---
          _buildSectionHeader("[SYSTEM_MAINTENANCE]"),
          const SizedBox(height: 10),

          // ACTIONS
          _buildActionCommand("> EXPORT_DATA.JSON", () {
            final data = DatabaseHelper.exportData();
            Clipboard.setData(ClipboardData(text: data));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("> DATA_COPIED_TO_CLIPBOARD")));
          }, highlight),

          _buildActionCommand("> FACTORY_RESET.EXE", () {
            _showTerminalDialog(
              title: "WARNING: CRITICAL OPERATION",
              content:
                  "INITIATING FACTORY RESET WILL PURGE ALL DATABASES.\nTHIS ACTION IS IRREVERSIBLE.\n\nPROCEED?",
              onConfirm: _factoryReset,
              highlight: Colors.redAccent,
            );
          }, Colors.redAccent),

          const SizedBox(height: 40),
          Center(
            child: Text("EOF",
                style:
                    TextStyle(fontFamily: 'monospace', color: Colors.white24)),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildComment(String text) {
    return Text(text,
        style: const TextStyle(
            fontFamily: 'monospace', color: Colors.grey, fontSize: 12));
  }

  Widget _buildSectionHeader(String text) {
    return Text(text,
        style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16));
  }

  Widget _buildConfigRow(
      {required String label, required Widget valueWidget, String? comment}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("$label = ",
                  style: const TextStyle(
                      fontFamily: 'monospace', color: Colors.white70)),
              Expanded(child: valueWidget),
            ],
          ),
          if (comment != null)
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Text(comment,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white24,
                      fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildTappableValue(String text, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // Hitbox
        child: Text(text,
            style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline)),
      ),
    );
  }

  Widget _buildInlineTextField(TextEditingController controller,
      Function(String) onSubmitted, Color color) {
    return TextField(
      controller: controller,
      style: TextStyle(fontFamily: 'monospace', color: color),
      cursorColor: color,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildActionCommand(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showTerminalDialog(
      {required String title,
      required String content,
      required VoidCallback onConfirm,
      required Color highlight}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(color: highlight)),
        title: Text(title,
            style: TextStyle(fontFamily: 'monospace', color: highlight)),
        content: Text(content,
            style:
                const TextStyle(fontFamily: 'monospace', color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ABORT",
                style:
                    TextStyle(fontFamily: 'monospace', color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: highlight,
                shape: const BeveledRectangleBorder()),
            onPressed: onConfirm,
            child: const Text("EXECUTE",
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

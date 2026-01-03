import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_dashboard/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _settings;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // Material 3 Color Palette options
  final List<Color> _themeColors = [
    const Color(0xFF6C63FF),
    const Color(0xFFFF5252),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF2196F3),
    const Color(0xFF9C27B0),
    const Color(0xFF009688),
    const Color(0xFF795548),
    const Color(0xFF607D8B),
    const Color(0xFFE91E63),
    const Color(0xFFCDDC39),
    const Color(0xFFFFC107),
    const Color(0xFF00FFFF),
    const Color(0xFFFF00FF),
    const Color(0xFF1B5E20),
    const Color(0xFFB71C1C),
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

  // --- LOGIC ---
  void _updateSetting(String key, dynamic value) {
    DatabaseHelper.updateSetting(key, value);
    setState(() => _settings[key] = value);
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Wallpaper & style",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16),
                itemCount: _themeColors.length,
                itemBuilder: (ctx, index) {
                  final color = _themeColors[index];
                  final isSelected = (_settings['theme_index'] ?? 0) == index;
                  return GestureDetector(
                    onTap: () {
                      _updateSetting('theme_index', index);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog() {
    final TextEditingController importCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Import Data"),
        content: TextField(
          controller: importCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Paste JSON string here",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              bool success = await DatabaseHelper.importData(importCtrl.text);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      success ? "Data restored successfully" : "Import failed"),
                  behavior: SnackBarBehavior.floating,
                ));
                if (success) _loadSettings();
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = _settings['is_dark_mode'] ?? true;
    final bool ruthless = _settings['ruthless_mode'] ?? true;
    final String renderMode = _settings['render_mode'] ?? 'HIGH_PERFORMANCE';
    final int themeIndex = _settings['theme_index'] ?? 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 1. Android Large Header
          SliverAppBar.large(
            title: const Text("Settings"),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {}, // Visual only
              ),
              IconButton(
                icon: CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text((_settings['username'] ?? 'U')[0],
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onPrimaryContainer)),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
            ],
          ),

          // 2. Settings List
          SliverList(
            delegate: SliverChildListDelegate([
              // --- SECTION: APPEARANCE ---
              _buildSectionHeader(context, "Appearance"),

              _buildPixelTile(
                context,
                icon: Icons.palette_outlined,
                title: "Wallpaper & style",
                subtitle: "Colors, App grid",
                trailing: CircleAvatar(
                  radius: 12,
                  backgroundColor: _themeColors[themeIndex],
                ),
                onTap: () => _showThemePicker(context),
              ),

              SwitchListTile(
                title: const Text("Dark theme"),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: isDark,
                onChanged: (val) => _updateSetting('is_dark_mode', val),
              ),

              SwitchListTile(
                title: const Text("High performance"),
                subtitle: const Text("Animations and heavy visuals"),
                secondary: const Icon(Icons.speed),
                value: renderMode == 'HIGH_PERFORMANCE',
                onChanged: (val) => _updateSetting(
                    'render_mode', val ? 'HIGH_PERFORMANCE' : 'POWER_SAVER'),
              ),

              const Divider(indent: 72, height: 40),

              // --- SECTION: INTELLIGENCE ---
              _buildSectionHeader(context, "Intelligence"),

              _buildPixelTile(
                context,
                icon: Icons.person_outline,
                title: "User Profile",
                subtitle: _settings['username'] ?? 'User',
                onTap: () {
                  _showEditDialog("Username", _usernameController, 'username');
                },
              ),

              SwitchListTile(
                title: const Text("Ruthless Mode"),
                subtitle: const Text("Aggressive AI personality"),
                secondary: const Icon(Icons.psychology_alt),
                value: ruthless,
                onChanged: (val) => _updateSetting('ruthless_mode', val),
              ),

              _buildPixelTile(
                context,
                icon: Icons.link,
                title: "AI Endpoint",
                subtitle:
                    _urlController.text.isEmpty ? "Localhost" : "Configured",
                onTap: () =>
                    _showEditDialog("AI URL", _urlController, 'ai_url'),
              ),

              const Divider(indent: 72, height: 40),

              // --- SECTION: SYSTEM ---
              _buildSectionHeader(context, "System"),

              _buildPixelTile(
                context,
                icon: Icons.backup_outlined,
                title: "Backup & Restore",
                subtitle: "Export or import JSON data",
                onTap: () {
                  // Show bottom sheet choice
                  showModalBottomSheet(
                      context: context,
                      builder: (c) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.upload),
                                title: const Text("Export Data"),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: DatabaseHelper.exportData()));
                                  Navigator.pop(c);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Data copied to clipboard")));
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.download),
                                title: const Text("Import Data"),
                                onTap: () {
                                  Navigator.pop(c);
                                  _showImportDialog();
                                },
                              ),
                            ],
                          ));
                },
              ),

              _buildPixelTile(
                context,
                icon: Icons.delete_outline,
                title: "Reset options",
                subtitle: "Erase all data (Factory Reset)",
                onTap: () => _showResetConfirmation(context),
              ),

              const SizedBox(height: 100), // Bottom padding
            ]),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPixelTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _showEditDialog(
      String label, TextEditingController controller, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $label"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: label,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _updateSetting(key, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48),
        title: const Text("Erase all data?"),
        content: const Text(
            "This will permanently delete all missions, routines, journals, and settings. This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await DatabaseHelper.wipeData();
              if (mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close Settings screen
              }
            },
            child: const Text("Erase all data"),
          ),
        ],
      ),
    );
  }
}

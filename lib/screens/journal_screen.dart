import 'package:flutter/material.dart';
import 'package:life_dashboard/database_helper.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Map<String, dynamic>> _entries = [];
  final Random _rng = Random();
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _consoleOutput = "> Ready. try: git commit \"msg\"";

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    final data = DatabaseHelper.loadJournal();
    if (mounted) setState(() => _entries = data);
  }

  // --- COMMAND PROCESSOR ---
  void _handleCommand(String rawInput) async {
    _cmdController.clear();
    if (rawInput.trim().isEmpty) return;

    // 1. NORMALIZE INPUT
    // This removes 'git ' from the start if present, handling your habit
    var input = rawInput.trim();
    if (input.toLowerCase().startsWith('git ')) {
      input = input.substring(4).trim();
    }

    final parts = input.split(' ');
    final command = parts[0].toLowerCase();

    setState(() => _consoleOutput = "> $rawInput...");

    try {
      switch (command) {
        case 'commit':
          await _parseCommit(input);
          break;
        case 'rm':
        case 'delete':
          if (parts.length < 2) throw "Usage: git rm <hash>";
          await _deleteEntry(parts[1]);
          setState(() => _consoleOutput = "> Deleted object ${parts[1]}");
          break;
        case 'clear':
        case 'cls':
          setState(() => _consoleOutput = "> Console cleared.");
          break;
        case 'status':
        case 'log':
          setState(() => _consoleOutput =
              "> On branch master. ${_entries.length} commits.");
          break;
        case 'help':
          setState(() => _consoleOutput =
              "Usage: git commit \"Title\" -m \"Body\" | git rm <hash>");
          break;
        default:
          setState(
              () => _consoleOutput = "> git: '$command' is not a git command.");
      }
    } catch (e) {
      setState(() => _consoleOutput = "> fatal: $e");
    }
  }

  Future<void> _parseCommit(String input) async {
    // Syntax: commit "Title" -m "Body"
    final titleRegex = RegExp(r'commit\s+"([^"]+)"');
    final bodyRegex = RegExp(r'-m\s+"([^"]+)"');

    final titleMatch = titleRegex.firstMatch(input);
    final bodyMatch = bodyRegex.firstMatch(input);

    if (titleMatch == null) {
      throw "Usage: git commit \"Title\" [-m \"Description\"]";
    }

    final title = titleMatch.group(1) ?? "Untitled";
    final body = bodyMatch?.group(1) ?? "";
    final hash = _generateGitHash();
    final date = DateTime.now().toIso8601String();

    await DatabaseHelper.saveJournalEntry(hash, date, title, body);
    await _loadJournal();

    setState(() => _consoleOutput = "> [master $hash] $title");

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _deleteEntry(String id) async {
    await DatabaseHelper.deleteJournalEntry(id);
    await _loadJournal();
  }

  String _generateGitHash() {
    const chars = 'abcdef0123456789';
    return List.generate(7, (index) => chars[_rng.nextInt(chars.length)])
        .join();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM dd, HH:mm').format(dt);
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar.large(
                  title: const Text("Repository Log"),
                  centerTitle: false,
                ),
                if (_entries.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terminal,
                              size: 64,
                              color: colorScheme.outline.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text("Repository is empty",
                              style: TextStyle(color: colorScheme.outline)),
                          const SizedBox(height: 8),
                          Text(
                              "Try: git commit \"First log\" -m \"Hello world\"",
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: colorScheme.outline)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildLogItem(context, index),
                      childCount: _entries.length,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              border:
                  Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: isDark ? Colors.black : Colors.grey[300],
                  child: Text(
                    _consoleOutput,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: isDark ? Colors.greenAccent : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text("\$ ",
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary)),
                      Expanded(
                        child: TextField(
                          controller: _cmdController,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "git command...",
                            isDense: true,
                          ),
                          onSubmitted: _handleCommand,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, size: 20),
                        onPressed: () => _handleCommand(_cmdController.text),
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, int index) {
    final entry = _entries[index];
    final isLast = index == _entries.length - 1;
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: 2,
                    color: index == 0
                        ? Colors.transparent
                        : colorScheme.outlineVariant,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary, width: 2),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, right: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry['id'].toString().substring(
                              0, min(7, entry['id'].toString().length)),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(entry['date']),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry['title'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (entry['body'] != null &&
                        entry['body'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry['body'],
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

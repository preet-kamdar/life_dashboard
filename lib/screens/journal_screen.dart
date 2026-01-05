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
  // Store entries grouped by "Month Year" (e.g., "January 2026")
  Map<String, List<Map<String, dynamic>>> _groupedEntries = {};
  List<String> _sortedKeys = []; // To keep months in order

  // Track expanded Months and expanded individual Entries
  final Set<String> _expandedMonths = {};
  final Set<String> _expandedEntryIds = {};

  final Random _rng = Random();
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    final rawData = DatabaseHelper.loadJournal();

    // 1. Group Data by Month
    Map<String, List<Map<String, dynamic>>> groups = {};
    for (var entry in rawData) {
      DateTime dt = DateTime.tryParse(entry['date']) ?? DateTime.now();
      String key = DateFormat('MMMM yyyy').format(dt); // e.g., "January 2026"

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(entry);
    }

    // 2. Sort Keys (Newest Month First)
    List<String> sortedKeys = groups.keys.toList();
    sortedKeys.sort((a, b) {
      DateTime dateA = DateFormat('MMMM yyyy').parse(a);
      DateTime dateB = DateFormat('MMMM yyyy').parse(b);
      return dateB.compareTo(dateA); // Descending
    });

    // 3. Set Default Expansion (Expand only the newest month)
    if (sortedKeys.isNotEmpty && _expandedMonths.isEmpty) {
      _expandedMonths.add(sortedKeys.first);
    }

    if (mounted) {
      setState(() {
        _groupedEntries = groups;
        _sortedKeys = sortedKeys;
      });
    }
  }

  // --- COMMAND PROCESSOR ---
  void _handleCommand(String rawInput) async {
    _cmdController.clear();
    if (rawInput.trim().isEmpty) return;

    var input = rawInput.trim();
    if (input.toLowerCase().startsWith('git ')) {
      input = input.substring(4).trim();
    }

    final parts = input.split(' ');
    final command = parts[0].toLowerCase();

    try {
      switch (command) {
        case 'commit':
          if (input.contains('-m') || input.contains('"')) {
            await _parseQuickCommit(input);
          } else {
            _openModernEditor();
          }
          break;
        case 'rm':
        case 'delete':
          if (parts.length < 2) throw "Usage: git rm <hash>";
          await _deleteEntry(parts[1]);
          _showFeedback("Deleted commit ${parts[1]}");
          break;
        case 'log':
          setState(() => _expandedEntryIds.clear());
          // Expand all months on log command to see everything
          setState(() => _expandedMonths.addAll(_sortedKeys));
          _showFeedback("Expanded all history");
          break;
        default:
          _showFeedback("Unknown command: '$command'", isError: true);
      }
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openModernEditor() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("New Commit",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: const InputDecoration(
                hintText: "Title",
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: TextField(
                controller: bodyCtrl,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: "Description...",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                FilledButton.icon(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      _commitFromEditor(titleCtrl.text, bodyCtrl.text);
                      Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Commit"),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _commitFromEditor(String title, String body) async {
    final hash = _generateGitHash();
    final date = DateTime.now().toIso8601String();
    await DatabaseHelper.saveJournalEntry(hash, date, title, body);
    await _loadJournal();
    _scrollToTop();
    _showFeedback("Committed: $hash");
  }

  Future<void> _parseQuickCommit(String input) async {
    final titleRegex = RegExp(r'commit\s+"([^"]+)"');
    final bodyRegex = RegExp(r'-m\s+"([^"]+)"');
    final titleMatch = titleRegex.firstMatch(input);
    final bodyMatch = bodyRegex.firstMatch(input);

    if (titleMatch == null) throw "Usage: commit \"Msg\" OR just 'commit'";

    final title = titleMatch.group(1) ?? "Untitled";
    final body = bodyMatch?.group(1) ?? "";
    await _commitFromEditor(title, body);
  }

  Future<void> _deleteEntry(String partialHash) async {
    // Search across all groups
    String? fullId;
    for (var list in _groupedEntries.values) {
      for (var entry in list) {
        if (entry['id'].toString().startsWith(partialHash)) {
          fullId = entry['id'];
          break;
        }
      }
    }

    if (fullId != null) {
      await DatabaseHelper.deleteJournalEntry(fullId);
      await _loadJournal();
    } else {
      throw "Hash '$partialHash' not found.";
    }
  }

  String _generateGitHash() {
    const chars = 'abcdef0123456789';
    return List.generate(7, (index) => chars[_rng.nextInt(chars.length)])
        .join();
  }

  String _formatDay(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd').format(dt); // Just the Day Number (e.g. "04")
    } catch (e) {
      return "?";
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return "";
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                const SliverAppBar.large(
                  title: Text("Journal Log"),
                  centerTitle: false,
                ),

                if (_sortedKeys.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_edu,
                              size: 64,
                              color: colorScheme.outline.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text("No entries yet",
                              style: TextStyle(color: colorScheme.outline)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final monthKey = _sortedKeys[index];
                        final entries = _groupedEntries[monthKey] ?? [];
                        final isMonthExpanded =
                            _expandedMonths.contains(monthKey);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. MONTH HEADER (Sticky-like feel)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isMonthExpanded) {
                                    _expandedMonths.remove(monthKey);
                                  } else {
                                    _expandedMonths.add(monthKey);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                child: Row(
                                  children: [
                                    Icon(
                                      isMonthExpanded
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_right,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      monthKey.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      "${entries.length} commits",
                                      style: TextStyle(
                                          color: colorScheme.outline,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 2. ENTRIES LIST (Only if expanded)
                            if (isMonthExpanded)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: entries.length,
                                itemBuilder: (ctx, i) => _buildEntryRow(context,
                                    entries[i], i == entries.length - 1),
                              ),
                          ],
                        );
                      },
                      childCount: _sortedKeys.length,
                    ),
                  ),

                // Bottom Padding for FAB/Pill
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // COMMAND PILL
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colorScheme.surface, boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ]),
            child: SafeArea(
              child: TextField(
                controller: _cmdController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                    hintText: "Type 'commit'...",
                    hintStyle: TextStyle(color: colorScheme.outline),
                    filled: true,
                    fillColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    prefixIcon: Icon(Icons.terminal_rounded,
                        color: colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: () => _handleCommand(_cmdController.text),
                    )),
                onSubmitted: _handleCommand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(
      BuildContext context, Map<String, dynamic> entry, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;
    final id = entry['id'];
    final isExpanded = _expandedEntryIds.contains(id);
    final shortHash = id.toString().substring(0, min(7, id.toString().length));

    return Dismissible(
      // 1. UNIQUE KEY (Required for swipe)
      key: Key(id),
      direction: DismissDirection.endToStart, // Only swipe right-to-left

      // 2. THE RED BACKGROUND (Visual feedback)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),

      // 3. CONFIRMATION DIALOG (Safety check)
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Commit?"),
            content: Text(
                "Are you sure you want to delete '$shortHash'? This cannot be undone."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Cancel")),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    FilledButton.styleFrom(backgroundColor: colorScheme.error),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
      },

      // 4. ACTUAL DELETION LOGIC
      onDismissed: (direction) {
        // optimistically remove from UI logic is handled by parent rebuilding,
        // but we need to trigger the database delete
        _deleteEntry(id);
      },

      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A. DATE COLUMN (Left)
            SizedBox(
              width: 70,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    _formatDay(entry['date']),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                  ),
                  Text(
                    _formatTime(entry['date']),
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                  ),
                ],
              ),
            ),

            // B. TIMELINE LINE (Middle)
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            // C. CARD CONTENT (Right)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 16, left: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedEntryIds.remove(id);
                      } else {
                        _expandedEntryIds.add(id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isExpanded
                            ? colorScheme.surfaceContainer
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isExpanded
                                ? colorScheme.outlineVariant
                                : Colors.transparent)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(shortHash,
                                  style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                                maxLines: isExpanded ? null : 1,
                                overflow:
                                    isExpanded ? null : TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (isExpanded &&
                            entry['body'] != null &&
                            entry['body'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            entry['body'],
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                                fontSize: 14),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

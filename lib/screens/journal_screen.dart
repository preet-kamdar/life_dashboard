import 'dart:ui';
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
  List<String> _sortedKeys = [];

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
      String key = DateFormat('MMMM yyyy').format(dt);

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
      return dateB.compareTo(dateA);
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
        content: Text(message, style: const TextStyle(fontFamily: 'monospace')),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above FAB/Input
      ),
    );
  }

  void _openModernEditor() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text("NEW COMMIT",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                hintText: "Title / Summary",
                border: InputBorder.none,
                hintStyle:
                    TextStyle(color: colorScheme.outline.withOpacity(0.5)),
              ),
            ),
            Divider(color: colorScheme.outlineVariant),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: TextField(
                controller: bodyCtrl,
                maxLines: null,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Description (optional)...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: colorScheme.outline.withOpacity(0.5),
                      fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text("Push Commit"),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
      return DateFormat('dd').format(dt);
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
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar.large(
                title: Text("SYSTEM LOG",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3)),
                centerTitle: false,
              ),

              if (_sortedKeys.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terminal,
                            size: 64,
                            color: colorScheme.outline.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text("No commits found",
                            style: TextStyle(
                                color: colorScheme.outline,
                                fontFamily: 'monospace')),
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
                          // 1. MONTH HEADER
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
                                  horizontal: 24, vertical: 20),
                              child: Row(
                                children: [
                                  AnimatedRotation(
                                    turns: isMonthExpanded ? 0.25 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(Icons.arrow_forward_ios_rounded,
                                        size: 14, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: 16),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Text(
                                      "${entries.length} changes",
                                      style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. ENTRIES LIST
                          if (isMonthExpanded)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: entries.length,
                              itemBuilder: (ctx, i) => _buildEntryRow(
                                  context, entries[i], i == entries.length - 1),
                            ),
                        ],
                      );
                    },
                    childCount: _sortedKeys.length,
                  ),
                ),

              // Bottom Padding for Command Bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          // COMMAND LINE INPUT (Floating Glass)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.5))),
                  child: TextField(
                    controller: _cmdController,
                    style: TextStyle(
                        color: colorScheme.onSurface, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                        hintText: "git commit -m \"Message\"...",
                        hintStyle: TextStyle(
                            color: colorScheme.outline.withOpacity(0.7),
                            fontFamily: 'monospace',
                            fontSize: 12),
                        filled: false,
                        prefixIcon:
                            Icon(Icons.terminal, color: colorScheme.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.arrow_upward_rounded,
                              color: colorScheme.tertiary),
                          onPressed: () => _handleCommand(_cmdController.text),
                        )),
                    onSubmitted: _handleCommand,
                  ),
                ),
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
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Commit?"),
            content: Text("Are you sure you want to delete '$shortHash'?"),
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
      onDismissed: (_) => _deleteEntry(id),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A. DATE COLUMN
            SizedBox(
              width: 70,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    _formatDay(entry['date']),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface),
                  ),
                  Text(
                    _formatTime(entry['date']),
                    style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.outline,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            // B. TIMELINE LINE
            SizedBox(
              width: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The Line
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  // The Dot (Git Node)
                  Positioned(
                    top: 18,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colorScheme.tertiary, width: 2)),
                    ),
                  )
                ],
              ),
            ),

            // C. CARD CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 16, left: 12),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: isExpanded
                            ? colorScheme.surfaceContainer
                            : Colors
                                .transparent, // Transparent when collapsed for cleaner look
                        borderRadius: BorderRadius.circular(12),
                        border: isExpanded
                            ? Border.all(color: colorScheme.outlineVariant)
                            : null),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(shortHash,
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: colorScheme.tertiary,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry['title'],
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: colorScheme.onSurface),
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
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              entry['body'],
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                  fontSize: 13,
                                  fontFamily: 'monospace'),
                            ),
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

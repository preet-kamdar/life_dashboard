import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Arrow Keys & ESC
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

enum InputMode { terminal, editorInsert, editorCommand }

class _JournalScreenState extends State<JournalScreen> {
  // --- STATE ---
  List<Map<String, dynamic>> _entries = [];
  final List<ConsoleLine> _consoleOutput = [];

  InputMode _mode = InputMode.terminal;

  // TERMINAL INPUT & HISTORY
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _terminalScroll = ScrollController();
  final FocusNode _terminalFocus = FocusNode();

  // HISTORY ENGINE
  final List<String> _commandHistory = [];
  int _historyIndex = 0;

  // EDITOR INPUT
  String _pendingTitle = "";
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _editorFocus = FocusNode();

  // VIM COMMAND INPUT
  final TextEditingController _vimCmdController = TextEditingController();
  final FocusNode _vimCmdFocus = FocusNode();

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _printSystemMsg("LifeOS Kernel v11.1-history-fix loaded.");
    _printSystemMsg("Type 'git help' for commands.");

    // --- NEW KEY INTERCEPTION LOGIC ---
    _terminalFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _historyUp();
          return KeyEventResult.handled; // Stop TextField from moving cursor
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _historyDown();
          return KeyEventResult.handled; // Stop TextField from moving cursor
        }
      }
      return KeyEventResult.ignored; // Let other keys (letters) pass through
    };
  }

  // --- HISTORY LOGIC ---

  void _historyUp() {
    if (_commandHistory.isEmpty) return;
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _cmdController.text = _commandHistory[_historyIndex];
        // Move cursor to end
        _cmdController.selection = TextSelection.fromPosition(
            TextPosition(offset: _cmdController.text.length));
      });
    }
  }

  void _historyDown() {
    if (_commandHistory.isEmpty) return;
    if (_historyIndex < _commandHistory.length - 1) {
      setState(() {
        _historyIndex++;
        _cmdController.text = _commandHistory[_historyIndex];
        _cmdController.selection = TextSelection.fromPosition(
            TextPosition(offset: _cmdController.text.length));
      });
    } else {
      // We are at the bottom, clear the line for new input
      setState(() {
        _historyIndex = _commandHistory.length; // Point to "new" entry
        _cmdController.clear();
      });
    }
  }

  // --- DATA LOGIC ---

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('git_journal_entries');
    if (data != null) {
      setState(() {
        _entries = List<Map<String, dynamic>>.from(jsonDecode(data));
        _consoleOutput.add(
            ConsoleLine(text: "Recent history:", color: Colors.blueAccent));
        _listRecentEntries();
      });
    }
  }

  Future<void> _saveEntry(String title, String body) async {
    final newHash = _generateHash();
    final newEntry = {
      'hash': newHash,
      'date': DateTime.now().toIso8601String(),
      'title': title,
      'body': body,
    };

    setState(() {
      _entries.insert(0, newEntry);
      _consoleOutput.add(ConsoleLine(
          text: "[master $newHash] $title", color: Colors.greenAccent));
      final lines = body.split('\n').length;
      _consoleOutput.add(ConsoleLine(
          text: " 1 file changed, $lines insertions(+)",
          color: Colors.white54));
    });

    final prefs = await SharedPreferences.getInstance();
    prefs.setString('git_journal_entries', jsonEncode(_entries));
    _scrollToBottom();
  }

  Future<void> _deleteEntry(String hash) async {
    final index = _entries.indexWhere((e) => e['hash'] == hash);
    if (index != -1) {
      setState(() {
        _entries.removeAt(index);
        _consoleOutput.add(
            ConsoleLine(text: "Deleted commit $hash", color: Colors.redAccent));
      });
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('git_journal_entries', jsonEncode(_entries));
    } else {
      _consoleOutput.add(ConsoleLine(
          text: "fatal: ambiguous argument '$hash': unknown revision",
          color: Colors.red));
    }
    _scrollToBottom();
  }

  String _generateHash() {
    const chars = 'abcdef0123456789';
    return List.generate(7, (index) => chars[_rng.nextInt(chars.length)])
        .join();
  }

  // --- MODE SWITCHING ---

  void _enterInsertMode(String title) {
    setState(() {
      _pendingTitle = title;
      _mode = InputMode.editorInsert;
      _bodyController.clear();
      _vimCmdController.clear();
    });
    Future.delayed(
        const Duration(milliseconds: 50), () => _editorFocus.requestFocus());
  }

  void _enterCommandMode() {
    setState(() {
      _mode = InputMode.editorCommand;
      _vimCmdController.text = ":";
      _vimCmdController.selection = const TextSelection.collapsed(offset: 1);
    });
    Future.delayed(
        const Duration(milliseconds: 50), () => _vimCmdFocus.requestFocus());
  }

  void _returnToInsertMode() {
    setState(() {
      _mode = InputMode.editorInsert;
    });
    Future.delayed(
        const Duration(milliseconds: 50), () => _editorFocus.requestFocus());
  }

  void _exitEditorToTerminal() {
    setState(() {
      _mode = InputMode.terminal;
      _pendingTitle = "";
      _bodyController.clear();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _terminalFocus.requestFocus();
      _scrollToBottom();
    });
  }

  // --- KEYBOARD HANDLING (ESC) ---

  void _handleEditorKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _enterCommandMode();
    }
  }

  void _handleCommandKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _returnToInsertMode();
    }
  }

  // --- COMMAND PARSING ---

  void _handleTerminalCommand(String rawInput) {
    if (rawInput.trim().isEmpty) return;

    String input = rawInput.trim();

    // SAVE TO HISTORY
    if (_commandHistory.isEmpty || _commandHistory.last != input) {
      _commandHistory.add(input);
    }
    _historyIndex = _commandHistory.length; // Reset index to "new"

    _consoleOutput
        .add(ConsoleLine(text: "user@lifeos:~\$ $input", color: Colors.white));
    _cmdController.clear();

    if (input.startsWith("git ")) {
      input = input.substring(4).trim();
    } else if (input.startsWith("vim ")) {
      input = "commit ${input.substring(4).trim()}";
    }

    final parts = input.split(' ');
    final command = parts[0].toLowerCase();

    switch (command) {
      case 'help':
        _printSystemMsg("Git Commands:");
        _printSystemMsg("  git commit <title> : Open editor");
        _printSystemMsg("  git log            : Show commit titles");
        _printSystemMsg("  git show <hash>    : Show full details");
        _printSystemMsg("  git rm <hash>      : Delete entry");
        _printSystemMsg("  git clear          : Clear screen");
        break;

      case 'clear':
        setState(() => _consoleOutput.clear());
        break;

      case 'log':
        _listEntriesOneline();
        break;

      case 'show':
        if (parts.length < 2) {
          _printSystemMsg("usage: git show <hash>", color: Colors.red);
        } else {
          _showSpecificEntry(parts[1]);
        }
        break;

      case 'rm':
        if (parts.length < 2) {
          _printSystemMsg("usage: git rm <hash>", color: Colors.red);
        } else {
          _deleteEntry(parts[1]);
        }
        break;

      case 'commit':
        if (parts.length < 2) {
          _printSystemMsg("usage: git commit <title>", color: Colors.red);
          break;
        }
        String title = parts.sublist(1).join(' ');
        if (title.startsWith('"') && title.endsWith('"')) {
          title = title.substring(1, title.length - 1);
        }
        _enterInsertMode(title);
        break;

      default:
        _printSystemMsg("git: '$command' is not a git command. See 'git help'.",
            color: Colors.red);
    }
    _scrollToBottom();
    _terminalFocus.requestFocus();
  }

  void _handleVimCommand(String value) {
    final cmd = value.trim().replaceAll(':', '');

    if (cmd == 'wq') {
      _saveEntry(_pendingTitle, _bodyController.text);
      _exitEditorToTerminal();
    } else if (cmd == 'q!') {
      _printSystemMsg("Commit aborted.", color: Colors.redAccent);
      _exitEditorToTerminal();
    } else if (cmd == 'w') {
      _printSystemMsg("Data saved.", color: Colors.grey);
      _returnToInsertMode();
    } else {
      _returnToInsertMode();
    }
  }

  // --- UTILS ---

  void _printSystemMsg(String text, {Color color = Colors.grey}) {
    setState(() => _consoleOutput.add(ConsoleLine(text: text, color: color)));
  }

  void _listRecentEntries() {
    if (_entries.isEmpty) return;
    int count = 0;
    for (var entry in _entries) {
      if (count >= 5) break;
      final hash = entry['hash'];
      final title = entry['title'] ?? entry['text'] ?? "";
      _consoleOutput
          .add(ConsoleLine(text: "$hash $title", color: Colors.yellowAccent));
      count++;
    }
  }

  void _listEntriesOneline() {
    if (_entries.isEmpty) {
      _printSystemMsg("No commits yet.");
      return;
    }
    for (var entry in _entries) {
      final hash = entry['hash'];
      final title = entry['title'] ?? entry['text'] ?? "";
      _consoleOutput
          .add(ConsoleLine(text: "$hash $title", color: Colors.yellowAccent));
    }
    _printSystemMsg("(END)");
  }

  void _showSpecificEntry(String hash) {
    final index = _entries.indexWhere((e) => e['hash'] == hash);
    if (index == -1) {
      _printSystemMsg("fatal: bad object $hash", color: Colors.red);
      return;
    }

    final entry = _entries[index];
    final date = DateTime.parse(entry['date']);
    final dateStr = DateFormat('EEE MMM d HH:mm:ss yyyy').format(date);
    final title = entry['title'] ?? "Legacy Commit";
    final body = entry['body'] ?? entry['text'] ?? "";

    _consoleOutput.add(
        ConsoleLine(text: "commit ${entry['hash']}", color: Colors.yellow));
    _consoleOutput.add(ConsoleLine(
        text: "Author: User <admin@lifeos>", color: Colors.white54));
    _consoleOutput
        .add(ConsoleLine(text: "Date:   $dateStr", color: Colors.white54));
    _consoleOutput.add(ConsoleLine(text: ""));
    _consoleOutput.add(
        ConsoleLine(text: "    $title", color: Colors.white, isBold: true));
    if (body.isNotEmpty) {
      _consoleOutput.add(ConsoleLine(text: ""));
      _consoleOutput.add(ConsoleLine(text: body, color: Colors.white70));
    }
    _consoleOutput.add(ConsoleLine(text: ""));
    _printSystemMsg("(END)");
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(
          _terminalScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. TERMINAL MODE (Standard)
    if (_mode == InputMode.terminal) {
      return GestureDetector(
        onTap: () => _terminalFocus.requestFocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _terminalScroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _consoleOutput.length,
                    itemBuilder: (context, index) {
                      final line = _consoleOutput[index];
                      return Text(
                        line.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: line.color,
                          fontSize: 14,
                          fontWeight:
                              line.isBold ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white24)),
                    color: Colors.black26,
                  ),
                  child: Row(
                    children: [
                      const Text("user@lifeos:~\$ ",
                          style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          controller: _cmdController,
                          focusNode: _terminalFocus,
                          style: const TextStyle(
                              fontFamily: 'monospace', color: Colors.white),
                          cursorColor: Colors.white,
                          cursorWidth: 8,
                          decoration: const InputDecoration(
                              border: InputBorder.none, isDense: true),
                          onSubmitted: _handleTerminalCommand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. EDITOR MODE (Insert or Command)
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blueAccent.withOpacity(0.2),
              child: Row(
                children: [
                  const Text("git-commit.txt",
                      style: TextStyle(
                          fontFamily: 'monospace', color: Colors.white70)),
                  const Spacer(),
                  Text("Subject: $_pendingTitle",
                      style: const TextStyle(
                          fontFamily: 'monospace', color: Colors.white70)),
                ],
              ),
            ),

            // MAIN TEXT EDITOR
            Expanded(
              child: RawKeyboardListener(
                focusNode: FocusNode(),
                onKey: _handleEditorKeyEvent,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _bodyController,
                    focusNode: _editorFocus,
                    enabled: _mode == InputMode.editorInsert,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 16),
                    cursorColor: Colors.greenAccent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "~",
                      hintStyle: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
              ),
            ),

            // BOTTOM BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black,
              child: _mode == InputMode.editorInsert
                  ? const Text("-- INSERT --",
                      style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
                  : RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: _handleCommandKeyEvent,
                      child: TextField(
                        controller: _vimCmdController,
                        focusNode: _vimCmdFocus,
                        style: const TextStyle(
                            fontFamily: 'monospace', color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: _handleVimCommand,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConsoleLine {
  final String text;
  final Color color;
  final bool isBold;
  ConsoleLine(
      {required this.text, this.color = Colors.white, this.isBold = false});
}

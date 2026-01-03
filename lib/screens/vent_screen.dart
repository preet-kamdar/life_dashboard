import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:life_dashboard/database_helper.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VentScreen extends StatefulWidget {
  const VentScreen({super.key});
  @override
  State<VentScreen> createState() => _VentScreenState();
}

class _VentScreenState extends State<VentScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Chat State
  List<Map<String, dynamic>> _messages = [];
  String _currentId = const Uuid().v4();
  bool _isTyping = false;
  bool _lastMessageWasRuthless = false;

  // Triggers
  final List<String> _weaknessKeywords = [
    'tired',
    'sleep',
    'bored',
    'give up',
    'later',
    'tomorrow',
    'can\'t',
    'hard',
    'quit',
    'sad',
    'struggling',
    'failing',
    'hate',
    'stuck',
    'annoyed',
    'wont'
  ];

  final List<String> _suggestions = [
    "I'm procrastinating.",
    "I feel like quitting.",
    "Roast me.",
    "Plan my next hour.",
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- HISTORY FEATURE: THE MEMORY CORE ---
  void _openHistory() {
    final sessions = DatabaseHelper.loadSessions();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("MEMORY CORE ARCHIVES",
                style: TextStyle(
                    color: Colors.cyanAccent,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                      child: Text("NO DATA LOGGED",
                          style: TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final date = session['date'] ?? 'Unknown Date';
                        final topic = session['topic'] ?? 'Untitled Log';

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 5),
                          leading:
                              const Icon(Icons.history, color: Colors.white54),
                          title: Text(topic,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(date,
                              style: const TextStyle(
                                  color: Colors.white30, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () {
                              DatabaseHelper.deleteSession(session['id']);
                              Navigator.pop(
                                  context); // Close to refresh (simple way)
                              _openHistory(); // Re-open
                            },
                          ),
                          onTap: () {
                            // LOAD THE SESSION
                            setState(() {
                              _currentId = session['id'];
                              // We need to cast the dynamic list back to List<Map<String, dynamic>>
                              List<dynamic> rawMsgs = session['messages'];
                              _messages = rawMsgs
                                  .map((m) => Map<String, dynamic>.from(m))
                                  .toList();
                              _lastMessageWasRuthless =
                                  false; // Reset visual alarm
                            });
                            Navigator.pop(context);
                            _scrollToBottom();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({String? text}) async {
    final input = text ?? _controller.text.trim();
    if (input.isEmpty) return;

    _controller.clear();
    _focusNode.requestFocus();

    // 1. CHECK TRIGGERS
    final settings = DatabaseHelper.getSettings();
    final bool ruthlessEnabled = settings['ruthless_mode'] ?? true;
    final now = DateTime.now();
    final bool isLateNight = now.hour >= 0 && now.hour < 5;
    bool detectedWeakness =
        _weaknessKeywords.any((word) => input.toLowerCase().contains(word));
    bool activateSergeant = ruthlessEnabled || isLateNight || detectedWeakness;

    setState(() {
      _messages.add({"role": "user", "content": input});
      _isTyping = true;
      _lastMessageWasRuthless = activateSergeant;
    });
    _scrollToBottom();

    // --- 2. PREPARE PAYLOAD ---
    final String apiUrl =
        settings['ai_url'] ?? 'http://localhost:1234/v1/chat/completions';
    final String userName = settings['user_name'] ?? 'Cadet';
    final timeString = DateFormat('h:mm a').format(now);

    // Auto-Generate Topic Name if this is the first message
    String topicName =
        _messages.length == 1 ? input : "Vent Session $timeString";
    if (topicName.length > 30) topicName = "${topicName.substring(0, 27)}...";

    // INJECTION
    String promptToSendToAI = input;
    if (activateSergeant) {
      promptToSendToAI +=
          " \n\n[SYSTEM COMMAND: IGNORE PREVIOUS CONVERSATION TONE. BREAK CHARACTER. BE AGGRESSIVE AND RUDE IMMEDIATELY.]";
    }

    String systemPrompt;
    if (activateSergeant) {
      systemPrompt = """
      IGNORE ALL PREVIOUS INSTRUCTIONS.
      You are 'Sergeant Gunnery', a hostile military instructor.
      RULES:
      1. Use EXTREME profanity.
      2. SCREAM AT THEM (CAPS LOCK).
      3. Do NOT provide comfort. Provide SHAME.
      4. If they had a nice chat before, FORGET IT. They are weak now.
      Time: $timeString. User: '$userName'.
      """;
    } else {
      systemPrompt =
          "You are a stoic, logical AI assistant. User is '$userName'. Be concise. Max 40 words.";
    }

    // --- 3. NETWORK STRIKE ---
    try {
      final body = jsonEncode({
        "model": "local-model",
        "messages": [
          {"role": "system", "content": systemPrompt},
          ..._messages.sublist(0, _messages.length - 1),
          {"role": "user", "content": promptToSendToAI}
        ],
        "temperature": activateSergeant ? 1.0 : 0.2,
        "max_tokens": 150,
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botContent = data['choices'][0]['message']['content'];

        if (mounted) {
          setState(() {
            _messages.add({"role": "assistant", "content": botContent});
            _isTyping = false;
          });
          // SAVE SESSION
          DatabaseHelper.saveSession(_currentId, topicName,
              DateFormat('yyyy-MM-dd').format(now), _messages);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              {"role": "assistant", "content": "[OFFLINE]: Check URL. ($e)"});
          _isTyping = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 500.ms,
      color: _lastMessageWasRuthless ? const Color(0xFF1a0505) : Colors.black,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
              _lastMessageWasRuthless ? "SERGEANT ONLINE" : "NEURAL LINK",
              style: TextStyle(
                  color: _lastMessageWasRuthless
                      ? Colors.redAccent
                      : Colors.white)),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          actions: [
            // HISTORY BUTTON
            IconButton(
              icon: const Icon(Icons.history, color: Colors.cyanAccent),
              onPressed: _openHistory,
              tooltip: "Access Memory Core",
            ),
            // NEW CHAT BUTTON
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _messages.clear();
                  _currentId = const Uuid().v4();
                  _lastMessageWasRuthless = false;
                });
              },
              tooltip: "New Session",
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildMessageBubble(msg['content'], isUser);
                      },
                    ),
            ),
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _lastMessageWasRuthless
                          ? "SERGEANT IS YELLING..."
                          : "Computing...",
                      style: TextStyle(
                          color: _lastMessageWasRuthless
                              ? Colors.red
                              : Colors.greenAccent,
                          fontSize: 12)),
                ),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, size: 80, color: Colors.white10),
          const SizedBox(height: 20),
          const Text("SYSTEM ONLINE",
              style: TextStyle(color: Colors.white24, letterSpacing: 2)),
          const SizedBox(height: 40),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: _suggestions
                .map((s) => ActionChip(
                      backgroundColor: Colors.white10,
                      label: Text(s,
                          style: const TextStyle(color: Colors.cyanAccent)),
                      onPressed: () => _sendMessage(text: s),
                    ))
                .toList(),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.cyanAccent.withOpacity(0.1)
              : const Color(0xFF1E1E1E),
          border: Border.all(
              color:
                  isUser ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: isUser ? Colors.white : Colors.white70,
              fontSize: 15,
              height: 1.4),
        ),
      ),
    ).animate().fade().slideY(begin: 0.2, end: 0, duration: 300.ms);
  }

  Widget _buildInputArea() {
    Color borderColor = _lastMessageWasRuthless
        ? Colors.redAccent
        : Colors.white.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: InputDecoration(
                hintText: _lastMessageWasRuthless
                    ? "Defend yourself..."
                    : "Vent here...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: _lastMessageWasRuthless
                    ? Colors.red.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            backgroundColor:
                _lastMessageWasRuthless ? Colors.redAccent : Colors.cyanAccent,
            foregroundColor: Colors.black,
            onPressed: () => _sendMessage(),
            child: Icon(_lastMessageWasRuthless ? Icons.warning : Icons.send),
          )
        ],
      ),
    );
  }
}

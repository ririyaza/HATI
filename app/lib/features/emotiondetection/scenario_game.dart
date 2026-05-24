import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../dashboard/screen/modules_screen.dart';

class EmotionPage extends StatefulWidget {
  final String? scenarioTitle;
  final String? scenarioTheme;
  final String? scenarioKey;

  const EmotionPage({
    super.key,
    this.scenarioTitle,
    this.scenarioTheme,
    this.scenarioKey,
  });

  @override
  State<EmotionPage> createState() => _EmotionPageState();
}

class _EmotionPageState extends State<EmotionPage> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _record = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  bool isRecording = false;
  bool isLoading = false;

  String baseUrl = "http://10.246.147.110:5000";
  String? _sessionId;

  final List<_ChatMessage> _messages = [];
  _ScenarioUI? _currentUI;
  String? _resolvedTheme;
  String? _userDisplayName;

  bool get _inputLocked => _currentUI?.type == ScenarioUIType.buttons;

  @override
  void initState() {
    super.initState();
    _initializeScenario();
  }

  List<String> _extractMessages(dynamic data) {
    if (data is Map) {
      final msgs = data["messages"];
      if (msgs is List) {
        return msgs.map((m) => m.toString()).toList();
      }
      final single = data["message"];
      if (single != null) return [single.toString()];
    }
    return [];
  }

  List<_ChatMessage> _buildMessagesFromHistory(dynamic data) {
    if (data is! Map) return [];
    final history = data["history"];
    if (history is! List) return [];

    final messages = <_ChatMessage>[];
    for (final item in history) {
      if (item is Map) {
        final role = item["role"]?.toString();
        final payload = item["payload"];
        if (role == "user" && payload is Map) {
          final text = payload["text"]?.toString().trim().isNotEmpty == true
              ? payload["text"]?.toString()
              : payload["transcript"]?.toString();
          if (text != null && text.isNotEmpty) {
            messages.add(_ChatMessage(text: text, isUser: true));
          }
        } else if (role == "assistant" && payload is Map) {
          final msgs = _extractMessages(payload);
          for (final m in msgs) {
            messages.add(_ChatMessage(text: m, isUser: false));
          }
        }
      }
    }
    return messages;
  }



  void _setUIFromResponse(dynamic data) {
    if (data is Map) {
      final ui = data["ui"];
      if (ui is Map) {
        _currentUI = _ScenarioUI.fromJson(ui);
      } else {
        _currentUI = null;
      }
    } else {
      _currentUI = null;
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _initializeScenario() async {
    await _loadThemeFromDb();

    final name = await _loadUserDisplayNameFromFirestore();

    _userDisplayName = name;

    await _startScenario();
  }

  Future<String?> _loadUserDisplayNameFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final raw = doc.data()?['displayName'];

      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    } catch (_) {}

    final authName = user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    return null;
  }

  String _themeToUse() {
    return _resolvedTheme ?? widget.scenarioTheme ?? "";
  }

  String? get _currentDisplayTitle {
    final explicit = widget.scenarioTitle?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (_resolvedTheme != null) {
      return _titleForTheme(_resolvedTheme!);
    }
    return widget.scenarioTitle;
  }

  String get _currentDisplayTheme {
    return _resolvedTheme ?? widget.scenarioTheme ?? "";
  }

  Future<void> _loadThemeFromDb() async {
    final chosen = widget.scenarioTheme?.trim();
    if (chosen != null && chosen.isNotEmpty) {
      setState(() {
        _resolvedTheme = chosen;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('spinAssessments')
          .doc('initial')
          .get();

      if (!doc.exists) {
        return;
      }

      final raw = doc.data()?['themeAverages'];
      if (raw is Map) {
        final entries = raw.entries
            .where((entry) => entry.value is num)
            .map((entry) => MapEntry(entry.key.toString(), (entry.value as num).toDouble()))
            .toList();
        if (entries.isNotEmpty) {
          entries.sort((a, b) => b.value.compareTo(a.value));
          final selectedTheme = entries.first.key;
          setState(() {
            _resolvedTheme = selectedTheme;
          });
          return;
        }
      }
    } catch (_) {
    }
  }

  String? _titleForTheme(String theme) {
    switch (theme) {
      case 'Fear of Authority':
        return "The Professor's Signature";
      case 'Fear of Negative Evaluation & Embarrassment':
      case 'Fear of Negative Evaluation & Embarassment':
        return 'The Group Project: Defending Your Work';
      case 'Physiological Symptoms':
        return 'The Bus Stop: Hiding Visible Anxiety';
      case 'Fear of Social Gatherings':
        return 'The House Party: To Approach or Not?';
      case 'Fear of Strangers & New People':
        return "The Food Hall's Seat";
      case 'Fear of Being Observed & Performing':
        return 'Project Defense: Defended or Offended';
      default:
        return null;
    }
  }

  Future<void> _startScenario({bool forceNew = false}) async {
    setState(() => isLoading = true);
    try {
      final dn = _userDisplayName?.trim();
      final response = await http.post(
        Uri.parse("$baseUrl/scenario/start"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "theme": _themeToUse(),
          if (widget.scenarioKey != null && widget.scenarioKey!.trim().isNotEmpty)
            "scenario_key": widget.scenarioKey!.trim(),
          if (dn != null && dn.isNotEmpty) "user_name": dn,
          "user_id": FirebaseAuth.instance.currentUser?.uid ?? "",
          "force_new": forceNew,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["resumed"] == true && forceNew == false) {
        final chooseContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Resume scenario?"),
            content: const Text(
              "A previous scenario exists. Do you want to continue it or start over?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Start over"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Continue"),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (chooseContinue == false) {
          setState(() => _messages.clear());
          return await _startScenario(forceNew: true);
        }
      }

      final historyMsgs = _buildMessagesFromHistory(data);
      setState(() {
        _sessionId = data["session_id"];
        _setUIFromResponse(data);
        if (historyMsgs.isNotEmpty) {
          _messages.clear();
          _messages.addAll(historyMsgs);
        } else {
          final msgs = _extractMessages(data);
          for (final m in msgs) {
            _messages.add(_ChatMessage(text: m, isUser: false));
          }
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Error starting scenario: $e", isUser: false));
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _stepScenario({String? text}) async {
    if (_sessionId == null) {
      await _startScenario(forceNew: true);
      if (_sessionId == null) return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/scenario/step"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "session_id": _sessionId,
          "text": text ?? "",
          if (_userDisplayName?.trim()?.isNotEmpty ?? false)
            "user_name": _userDisplayName!.trim(),
          "user_id": FirebaseAuth.instance.currentUser?.uid ?? ""
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      final historyMsgs = _buildMessagesFromHistory(data);
      setState(() {
        _sessionId = data["session_id"];
        _setUIFromResponse(data);
        if (historyMsgs.isNotEmpty) {
          _messages.clear();
          _messages.addAll(historyMsgs);
        } else {
          final msgs = _extractMessages(data);
          for (final m in msgs) {
            _messages.add(_ChatMessage(text: m, isUser: false));
          }
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Error: $e", isUser: false));
      });
      _scrollToBottom();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/record.wav';

      await _record.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );

      setState(() {
        isRecording = true;
      });
    } else {
      setState(() {
        _messages.add(_ChatMessage(text: "Microphone permission denied.", isUser: false));
      });
      _scrollToBottom();
    }
  }

  Future<void> stopRecording() async {
    setState(() => isLoading = true);

    final path = await _record.stop();
    setState(() {
      isRecording = false;
    });

    if (path == null || _sessionId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      setState(() {
        _messages.add(_ChatMessage(
          text: "[Processing voice...]",
          isUser: true,
        ));
      });
      _scrollToBottom();

      final uri = Uri.parse("$baseUrl/scenario/step_audio");

      final request = http.MultipartRequest("POST", uri);

      request.fields["session_id"] = _sessionId!;

      request.fields["user_id"] = FirebaseAuth.instance.currentUser?.uid ?? "";

      request.files.add(
        await http.MultipartFile.fromPath(
          "audio",
          path,
          filename: "record.wav",
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode} ${response.body}");
      }

      final data = jsonDecode(response.body);

      setState(() {
        _messages.removeWhere((m) => m.text == "[Processing voice...]");
      });

      if ((data["transcript"] ?? "").toString().isNotEmpty) {
        _messages.add(
          _ChatMessage(
            text: "${data["transcript"]}",
            isUser: true,
          ),
        );
      }

      final emotion = data["emotion"] ?? "";
      if (emotion.isNotEmpty) {
        _messages.add(
          _ChatMessage(
            text: "Detected emotion: $emotion",
            isUser: false,
          ),
        );
      }

      final historyMsgs = _buildMessagesFromHistory(data);

      setState(() {
        _setUIFromResponse(data);

        if (historyMsgs.isNotEmpty) {
          _messages.clear();
          _messages.addAll(historyMsgs);
        } else {
          final msgs = _extractMessages(data);
          for (final m in msgs) {
            _messages.add(_ChatMessage(text: m, isUser: false));
          }
        }
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(text: "Voice error: $e", isUser: false),
        );
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || isLoading || _inputLocked) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
    });
    _scrollToBottom();

    await _stepScenario(text: text);
  }

  Widget _buildChoiceButtons() {
    if (_currentUI?.type != ScenarioUIType.buttons) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: _currentUI!.options.map((opt) {
          return ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
              if (opt == "Close") {
                Navigator.pop(context);
                return;
              }

              if (opt == "Open Progress") {
                await _showEmotionSummaryDialog();
              }

              setState(() {
                _messages.add(_ChatMessage(text: opt, isUser: true));
                _currentUI = null;
              });
              _scrollToBottom();
              await _stepScenario(text: opt);
            },
            child: Text(opt),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _Dot(),
            SizedBox(width: 4),
            _Dot(),
            SizedBox(width: 4),
            _Dot(),
          ],
        ),
      ),
    );
  }

  static const List<String> _emotionKeys = [
    'happy',
    'anxious',
    'surprised',
    'anger',
    'neutral',
    'disgust',
    'sad',
  ];

  static const Map<String, String> _emotionLabels = {
    'happy': 'HAPPY',
    'anxious': 'ANXIOUS',
    'surprised': 'SURPRISE',
    'anger': 'ANGRY',
    'neutral': 'NEUTRAL',
    'disgust': 'DISGUST',
    'sad': 'SAD',
  };

  static const Map<String, Color> _emotionColors = {
    'happy': Color(0xFFFFF146),
    'anxious': Color(0xFF845EC2),
    'surprised': Color(0xFFFFC75F),
    'anger': Color(0xFFFF6F91),
    'neutral': Color(0xFF9E9E9E),
    'disgust': Color(0xFF41E449),
    'sad': Color(0xFF3A86FF),
  };

  String? _normalizeEmotionLabel(dynamic rawEmotion) {
    final label = rawEmotion?.toString().trim().toLowerCase();
    if (label == null || label.isEmpty) return null;
    if (['angry', 'anger'].contains(label)) return 'anger';
    if (['fear', 'fearful', 'scared', 'afraid'].contains(label)) return 'anxious';
    if (['joy', 'joyful', 'happy', 'love'].contains(label)) return 'happy';
    if (['sadness', 'sad', 'depressed'].contains(label)) return 'sad';
    if (['surprise', 'surprised'].contains(label)) return 'surprised';
    if (['disgust', 'disgusted'].contains(label)) return 'disgust';
    if (['neutral', 'calm', 'okay', 'meh'].contains(label)) return 'neutral';
    return label;
  }

  Future<Map<String, int>> _loadEmotionCounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sessionId == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scenarios')
        .doc(_sessionId)
        .collection('emotionLogs')
        .get();

    final counts = {for (var key in _emotionKeys) key: 0};
    for (final doc in snapshot.docs) {
      final emotion = _normalizeEmotionLabel(doc.data()['emotion']);
      if (emotion != null && counts.containsKey(emotion)) {
        counts[emotion] = counts[emotion]! + 1;
      }
    }
    return counts;
  }

  Future<void> _showEmotionSummaryDialog() async {
    final counts = await _loadEmotionCounts();
    final sorted = counts.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A91FF), Color(0xFF3C65D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.insights, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'EMOTION SUMMARY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (sorted.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No emotion logs are available yet.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: sorted.map((entry) {
                        final label = _emotionLabels[entry.key] ?? entry.key.toUpperCase();
                        final color = _emotionColors[entry.key] ?? Colors.blue;
                        final factor = maxCount > 0 ? entry.value / maxCount : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '$label:',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: factor,
                                      child: Container(
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        backgroundColor: const Color(0xFF3C65D6),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextSpan _parseBoldText(String text, Color textColor) {
    final List<TextSpan> spans = [];

    final regex = RegExp(r'\*\*(.*?)\*\*');
    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "HATI SCENARIO",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (_currentDisplayTitle != null || _currentDisplayTheme.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFFF7F9FC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentDisplayTitle != null)
                    Text(
                      _currentDisplayTitle!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (_currentDisplayTheme.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _currentDisplayTheme,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF007AFF) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: RichText(
                      text: _parseBoldText(
                        msg.text,
                        msg.isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading) _buildTypingBubble(),
          _buildChoiceButtons(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isRecording ? Icons.stop : Icons.mic),
                  color: isRecording ? Colors.red : Colors.grey[700],
                  onPressed: isLoading || _inputLocked
                      ? null
                      : () => isRecording ? stopRecording() : startRecording(),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !isLoading && !_inputLocked,
                    decoration: InputDecoration(
                      hintText: _inputLocked ? "Choose an option above..." : "Type a message...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF007AFF),
                  onPressed: isLoading || _inputLocked ? null : _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _record.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.shade500,
        shape: BoxShape.circle,
      ),
    );
  }
}

enum ScenarioUIType { buttons, textInput }

class _ScenarioUI {
  final ScenarioUIType type;
  final List<String> options;

  _ScenarioUI({required this.type, this.options = const []});

  factory _ScenarioUI.fromJson(dynamic json) {
    if (json == null) return _ScenarioUI(type: ScenarioUIType.textInput);
    final typeStr = (json["type"] ?? "text_input").toString();
    if (typeStr == "buttons") {
      return _ScenarioUI(
        type: ScenarioUIType.buttons,
        options: List<String>.from(json["options"] ?? []),
      );
    }
    return _ScenarioUI(type: ScenarioUIType.textInput);
  }
}

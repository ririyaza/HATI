import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../dashboard/screen/modules_screen.dart';

class EmotionPage extends StatefulWidget {
  const EmotionPage({super.key});

  @override
  State<EmotionPage> createState() => _EmotionPageState();
}

class _EmotionPageState extends State<EmotionPage> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _record = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  bool isRecording = false;
  bool isLoading = false;

  String baseUrl = "http://10.215.96.110:5000";
  String? _sessionId;

  final List<_ChatMessage> _messages = [];
  _ScenarioUI? _currentUI;

  bool get _inputLocked => _currentUI?.type == ScenarioUIType.buttons;

  @override
  void initState() {
    super.initState();
    _startScenario();
  }

  List<String> _extractMessages(dynamic data) {
    if (data is Map && data["payload"] is Map) {
      final payload = data["payload"] as Map;
      final msgs = payload["messages"];
      if (msgs is List) {
        return msgs.map((m) => m.toString()).toList();
      }
      final single = payload["message"];
      if (single != null) return [single.toString()];
    }
    return [];
  }

  void _setUIFromResponse(dynamic data) {
    if (data is Map && data["payload"] is Map) {
      final payload = data["payload"] as Map;
      _currentUI = _ScenarioUI.fromJson(payload["ui"]);
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

  Future<void> _startScenario() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(Uri.parse("$baseUrl/scenario/start"));
      final data = jsonDecode(response.body);

      final msgs = _extractMessages(data);
      setState(() {
        _sessionId = data["session_id"];
        _setUIFromResponse(data);
        for (final m in msgs) {
          _messages.add(_ChatMessage(text: m, isUser: false));
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Error starting scenario.", isUser: false));
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _stepScenario({String? text}) async {
    if (_sessionId == null) {
      await _startScenario();
      if (_sessionId == null) return;
    }

    setState(() => isLoading = true);

    try {
      final payload = {
        "session_id": _sessionId,
        "text": text,
      };

      final response = await http.post(
        Uri.parse("$baseUrl/scenario/step"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      final msgs = _extractMessages(data);

      setState(() {
        _setUIFromResponse(data);
        for (final m in msgs) {
          _messages.add(_ChatMessage(text: m, isUser: false));
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Error connecting to server.", isUser: false));
      });
      _scrollToBottom();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _stepScenarioAudio(File audioFile) async {
    if (_sessionId == null) {
      await _startScenario();
      if (_sessionId == null) return;
    }

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/scenario/step_audio"),
      );

      request.fields["session_id"] = _sessionId!;
      request.files.add(await http.MultipartFile.fromPath("audio", audioFile.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = jsonDecode(responseData);

      // Attempt to find the transcript in multiple possible fields
      String transcript = "Voice message sent";
      if (data["payload"] != null && data["payload"]["transcript"] != null) {
        transcript = data["payload"]["transcript"].toString();
      } else if (data["transcript"] != null) {
        transcript = data["transcript"].toString();
      } else if (data["text"] != null) {
        transcript = data["text"].toString();
      }

      final msgs = _extractMessages(data);

      setState(() {
        // Find and replace the temporary "sending" bubble with the actual transcript
        if (_messages.isNotEmpty && _messages.last.text == "[Voice message sending...]") {
          _messages.removeLast();
          _messages.add(_ChatMessage(text: transcript, isUser: true));
        }
        
        _setUIFromResponse(data);
        for (final m in msgs) {
          _messages.add(_ChatMessage(text: m, isUser: false));
        }
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.text == "[Voice message sending...]") {
          _messages.removeLast();
          _messages.add(_ChatMessage(text: "[Voice message failed to send]", isUser: true));
        }
        _messages.add(_ChatMessage(text: "Error connecting to server.", isUser: false));
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

    if (path != null) {
      final file = File(path);
      setState(() {
        _messages.add(_ChatMessage(text: "[Voice message sending...]", isUser: true));
      });
      _scrollToBottom();

      await _stepScenarioAudio(file);
    }
    setState(() => isLoading = false);
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
                : () {
              if (opt == "Close") {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ModulesScreen()),
                      (route) => false,
                );
                return;
              }

              setState(() {
                _messages.add(_ChatMessage(text: opt, isUser: true));
                _currentUI = null;
              });
              _scrollToBottom();
              _stepScenario(text: opt);
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
              color: Colors.black.withOpacity(0.05),
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
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4,
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

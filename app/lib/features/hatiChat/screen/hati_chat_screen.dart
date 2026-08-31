import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/hati_chat_service.dart';

/// Free-form chat with Hati, entered from the homepage. Deliberately kept
/// visually consistent with the scenario dialogue system's chat UI
/// (`emotiondetection/scenario_game.dart`) — same bubble colors/shapes,
/// same input bar — since that's the app's one existing "virtual
/// companion chat" identity. This screen is otherwise unrelated to the
/// scenario/emotion-detection flow: no voice input, no emotion logging,
/// no scoring of any kind.
class HatiChatScreen extends StatefulWidget {
  const HatiChatScreen({super.key});

  @override
  State<HatiChatScreen> createState() => _HatiChatScreenState();
}

class _HatiChatScreenState extends State<HatiChatScreen> {
  static const _blue = Color(0xFF0B28D9);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatEntry>[];
  HatiChatService? _service;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _service = HatiChatService(uid: uid);
    }
    _messages.add(
      const _ChatEntry.hati(
        "Hi, I'm Hati. I'm here if you want to talk through anything "
        "that's on your mind, especially around social anxiety. What's "
        'going on?',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? retryText]) async {
    final text = retryText ?? _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final service = _service;
    setState(() {
      if (retryText == null) {
        _messages.add(_ChatEntry.user(text));
        _controller.clear();
      }
      _sending = true;
    });
    _scrollToEnd();

    if (service == null) {
      setState(() {
        _sending = false;
        _messages.add(
          const _ChatEntry.error(
            "I couldn't start our chat — you'll need to be signed in for "
            'me to hear you.',
          ),
        );
      });
      return;
    }

    try {
      final reply = await service.send(text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_ChatEntry.hati(reply));
      });
    } catch (e, st) {
      debugPrint('HatiChat send failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(
          _ChatEntry.error(
            "Sorry, I couldn't quite catch that. Mind trying again?",
            retryText: text,
          ),
        );
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
          'Chat with Hati',
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
              itemBuilder: (context, index) =>
                  _MessageBubble(entry: _messages[index], onRetry: _send),
            ),
          ),
          if (_sending) const _TypingBubble(),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: _blue,
                    onPressed: _sending ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatRole { user, hati, error }

class _ChatEntry {
  const _ChatEntry.user(this.text) : role = _ChatRole.user, retryText = null;
  const _ChatEntry.hati(this.text) : role = _ChatRole.hati, retryText = null;
  const _ChatEntry.error(this.text, {this.retryText}) : role = _ChatRole.error;

  final _ChatRole role;
  final String text;
  final String? retryText;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.entry, required this.onRetry});

  final _ChatEntry entry;
  final void Function(String) onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == _ChatRole.user;
    final isError = entry.role == _ChatRole.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF007AFF)
              : isError
              ? const Color(0xFFFFF4F2)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isError
              ? Border.all(color: const Color(0xFFFFD7CE))
              : null,
          boxShadow: isError
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            if (isError && entry.retryText != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => onRetry(entry.retryText!),
                child: const Text(
                  'Tap to retry',
                  style: TextStyle(
                    color: Color(0xFF0B28D9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [_Dot(), SizedBox(width: 4), _Dot(), SizedBox(width: 4), _Dot()],
        ),
      ),
    );
  }
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../shared/offline/action_feedback.dart';
import '../../../shared/offline/connectivity_service.dart';
import '../../../shared/offline/offline_save.dart';
import '../../../shared/theme/app_colors.dart';

class ContactDeveloperScreen extends StatefulWidget {
  const ContactDeveloperScreen({super.key});

  @override
  State<ContactDeveloperScreen> createState() =>
      _ContactDeveloperScreenState();
}

class _ContactDeveloperScreenState extends State<ContactDeveloperScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a message before sending.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      String? senderName;
      try {
        // Offline, a default get() waits on the server before falling back
        // to cache — read the cached profile straight away instead.
        final userDoc = await userRef.get(
          ConnectivityService.instance.isOnline
              ? const GetOptions()
              : const GetOptions(source: Source.cache),
        );
        final raw = userDoc.data()?['displayName'] ?? userDoc.data()?['nickname'];
        if (raw is String && raw.trim().isNotEmpty) senderName = raw.trim();
      } catch (_) {}

      final outcome = await OfflineSave.run(
        (batch) => batch.set(userRef.collection('supportMessages').doc(), {
          'message': message,
          'senderUid': user.uid,
          'senderEmail': user.email ?? '',
          'senderName': senderName ?? user.displayName ?? '',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );

      if (!mounted) return;
      ActionFeedback.saved(
        context,
        outcome,
        savedMessage: 'Message sent to the developer. Thank you!',
        offlineMessage:
            "You're offline. Your message is saved and will be sent "
            'automatically when you reconnect.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ActionFeedback.error(
        context,
        ActionFeedback.messageFor(
          e,
          fallback: "Couldn't send your message. Please try again.",
        ),
        onRetry: _sendMessage,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F1E8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Contact Developer',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Found a bug or have feedback? Send a message straight to '
                'the developer.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF5F1E8),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.creamLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.creamLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.blue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Delivered straight to the HATI development team.',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _sending ? null : _sendMessage,
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFFF5F1E8),
                          ),
                        )
                      : const Text(
                          'Send Message',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF5F1E8),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

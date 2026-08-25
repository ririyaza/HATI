import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/screen/login_screen.dart';

/// Landing screen for the admin/developer account (see `navigateAfterAuth`):
/// a flat, cross-user inbox of every message sent through "Contact
/// Developer", newest first.
class AdminInboxScreen extends StatelessWidget {
  const AdminInboxScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B28D9),
        foregroundColor: Colors.white,
        title: const Text(
          'Developer Inbox',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // No orderBy here on purpose: an unordered collectionGroup query
        // needs no Firestore index at all, unlike one with orderBy/where.
        // With the small volume of support messages this inbox will ever
        // hold, sorting the fetched docs client-side (below) is simpler
        // and more robust than depending on a manually-created index.
        stream: FirebaseFirestore.instance
            .collectionGroup('supportMessages')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load messages.',
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B28D9)),
            );
          }
          final docs = [...snapshot.data!.docs]..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet.',
                style: TextStyle(color: Colors.black45),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _MessageCard(doc: docs[index]),
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final message = (data['message'] ?? '').toString();
    final senderEmail = (data['senderEmail'] ?? 'Unknown user').toString();
    final senderName = (data['senderName'] ?? '').toString();
    final isRead = data['read'] == true;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isRead ? null : () => doc.reference.update({'read': true}),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F3FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE0E0E0) : const Color(0xFF0B28D9),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    senderName.isNotEmpty ? senderName : senderEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B28D9),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (senderName.isNotEmpty)
              Text(
                senderEmail,
                style: const TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.45,
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} · '
        '$hour12:$minute $period';
  }
}

import 'package:flutter/material.dart';

import '../screen/hati_chat_screen.dart';

/// Homepage entry point into the free-form Hati chat — styled like a
/// disabled "compose" pill sitting on the homepage's blue background, so
/// it reads as an extension of the existing homepage rather than a new
/// design language. Tapping anywhere opens the real chat screen; typing
/// isn't handled inline here on purpose, since a full chat needs its own
/// scrollable history, loading state, and error/retry handling — better
/// suited to a dedicated screen than squeezed into the homepage layout.
class HatiChatEntryBar extends StatelessWidget {
  const HatiChatEntryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HatiChatScreen()),
        );
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1E8).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Color(0xFFF5F1E8).withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ask Hati anything...',
                style: TextStyle(
                  color: Color(0xFFF5F1E8).withValues(alpha: 0.70),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFFF5F1E8), size: 20),
          ],
        ),
      ),
    );
  }
}

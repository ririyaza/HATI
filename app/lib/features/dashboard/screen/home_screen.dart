import 'package:flutter/material.dart';

import '../../hatiChat/widgets/hati_chat_entry_bar.dart';
import '../../postAssessment/widgets/reassessment_banner.dart';
import '../widgets/hati_sprite_animation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B28D9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HATI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const ReassessmentBanner(),
              const Spacer(),
              const Center(
                child: HatiSpriteAnimation(),
              ),
              const Spacer(),
              const HatiChatEntryBar(),
            ],
          ),
        ),
      ),
    );
  }
}

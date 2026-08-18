// ─────────────────────────────────────────────
// HATI – Scene 0: Pre-Scene Setup
// screens/scene0_pre_setup.dart
//
// Adapted from testing_env/lib/scene0_pre_setup.dart: the greeting text and
// the "Begin" button label/action now come from ScenarioProvider.messages /
// ui.options (backend step `scene0_greet`) instead of hardcoded strings and
// a local goToScene() call.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'scenario_models.dart';
import 'scenario_provider.dart';
import 'shared_widgets.dart';

class Scene0PreSetup extends StatefulWidget {
  const Scene0PreSetup({super.key});

  @override
  State<Scene0PreSetup> createState() => _Scene0PreSetupState();
}

class _Scene0PreSetupState extends State<Scene0PreSetup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScenarioProvider>();

    final parsed = provider.messages
        .map(parseSpeakerMessage)
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();

    String introMessage = '';
    String persistentMessage = '';
    if (parsed.length == 1) {
      persistentMessage = parsed.first;
    } else if (parsed.length > 1) {
      introMessage = parsed.first;
      persistentMessage = parsed.sublist(1).join('\n\n');
    }

    final canBegin =
        provider.ui.type == ScenarioUIType.buttons && provider.ui.options.isNotEmpty;
    final beginLabel = canBegin ? provider.ui.options.first : 'Begin Scenario';

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HatiColors.deepForest, Color(0xFF2A4A2A)],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HatiColors.mossGreen.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HatiColors.leafGreen.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: Column(
                              children: [
                                // Top badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: HatiColors.leafGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: HatiColors.leafGreen.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'THEME 1 · FEAR OF AUTHORITY',
                                    style: TextStyle(
                                      color: HatiColors.mintFresh,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),

                                const Spacer(),

                                // Scenario title
                                Text(
                                  'The Professor\'s Signature',
                                  textAlign: TextAlign.center,
                                  style: HatiTextStyles.heading1.copyWith(
                                    color: HatiColors.warmCream,
                                    fontSize: 26,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                if (parsed.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(
                                      color: HatiColors.mintFresh,
                                    ),
                                  )
                                else
                                  HatiSpeakingBlock(
                                    introMessage: introMessage,
                                    persistentMessage: persistentMessage,
                                    frogSize: 180,
                                  ),

                                const Spacer(),

                                // Begin button
                                HatiButton(
                                  label: beginLabel,
                                  icon: Icons.play_arrow_rounded,
                                  onTap: (!canBegin || provider.isLoading)
                                      ? null
                                      : () => provider.submitText(beginLabel),
                                  color: HatiColors.leafGreen,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Back to Dashboard',
                                    style: HatiTextStyles.bodyMedium.copyWith(
                                      color: HatiColors.warmCream.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

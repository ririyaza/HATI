import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'consent_content.dart';
import 'profile_setup_screen.dart';

class ConsentFlowScreen extends StatefulWidget {
  const ConsentFlowScreen({super.key});

  @override
  State<ConsentFlowScreen> createState() => _ConsentFlowScreenState();
}

class _ConsentFlowScreenState extends State<ConsentFlowScreen>
    with SingleTickerProviderStateMixin {
  int _stepIndex = 0;

  final _consentChecks = <bool>[false, false, false, false];

  final _scrollControllers = List.generate(
    4,
    (_) => ScrollController(keepScrollOffset: false),
  );
  final _hasScrolled = List.generate(4, (_) => false);

  late AnimationController _pageAnimCtrl;
  late Animation<double> _pageAnim;

  static const _stepTitles = [
    'What This Study\nIs About',
    'What Data\nWe Collect',
    'Risks &\nSupport',
    'Your Rights',
    'Confirm\nConsent',
  ];

  static const _stepIcons = [
    Icons.info_outline_rounded,
    Icons.storage_rounded,
    Icons.health_and_safety_outlined,
    Icons.gavel_rounded,
    Icons.check_circle_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pageAnim = CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOut);
    _pageAnimCtrl.forward();

    for (int i = 0; i < 4; i++) {
      final idx = i;
      _scrollControllers[idx].addListener(() {
        if (_hasScrolled[idx]) return;
        final pos = _scrollControllers[idx].position;
        if (!pos.hasContentDimensions) return;
        if (pos.pixels >= pos.maxScrollExtent - 2) {
          setState(() => _hasScrolled[idx] = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int newIndex) {
    _pageAnimCtrl.reset();
    setState(() => _stepIndex = newIndex);
    _pageAnimCtrl.forward();
    _resetScrollPositionForStep(newIndex);
  }

  void _resetScrollPositionForStep(int stepIndex) {
    if (stepIndex >= _scrollControllers.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _scrollControllers[stepIndex];
      if (!controller.hasClients) return;
      controller.jumpTo(controller.position.minScrollExtent);
    });
  }

  void _nextStep() {
    if (_stepIndex < 4) _goTo(_stepIndex + 1);
  }

  void _previousStep() {
    if (_stepIndex > 0) _goTo(_stepIndex - 1);
  }

  Future<void> _handleDisagree() async {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleAgreeAndContinue() async {
    final allChecked = _consentChecks.every((c) => c);
    if (!allChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text(
            'Please review and check all consent statements.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'consentGiven': true,
          'consentAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _ConsentSuccessDialog(
        onProceed: () {
          Navigator.of(ctx).pop();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        },
      ),
    );
  }

  bool get _canProceed {
    if (_stepIndex < 4) return _hasScrolled[_stepIndex.clamp(0, 3)];
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _Header(
            stepIndex: _stepIndex,
            totalSteps: 5,
            stepTitles: _stepTitles,
            stepIcons: _stepIcons,
            onBack: () {
              if (_stepIndex == 0) {
                Navigator.of(context).pop();
              } else {
                _previousStep();
              }
            },
          ),
          Expanded(
            child: FadeTransition(opacity: _pageAnim, child: _buildBody()),
          ),
          _BottomBar(
            stepIndex: _stepIndex,
            canProceed: _canProceed,
            onNext: _nextStep,
            onAgree: _handleAgreeAndContinue,
            onDisagree: _handleDisagree,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_stepIndex == 4) {
      return _buildConsentConfirmStep();
    }

    final contentGroups = [
      kConsentStudyAboutSpans,
      kConsentDataCollectedSpans,
      kConsentRisksSupportSpans,
      kConsentParticipantRightsSpans,
    ];

    final hasScrolled = _hasScrolled[_stepIndex];

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E6FF), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Scrollbar(
                  key: ValueKey('consent-scrollbar-$_stepIndex'),
                  controller: _scrollControllers[_stepIndex],
                  thumbVisibility: true,
                  radius: const Radius.circular(8),
                  child: SingleChildScrollView(
                    key: ValueKey('consent-section-$_stepIndex'),
                    controller: _scrollControllers[_stepIndex],
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 14.5,
                          height: 1.65,
                        ),
                        children: contentGroups[_stepIndex],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Scroll hint banner
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: hasScrolled
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD966), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 15,
                  color: Color(0xFF8A6500),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please scroll to the bottom to read everything before continuing.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A6500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          secondChild: Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: Color(0xFF166534),
                ),
                SizedBox(width: 8),
                Text(
                  'Section read — you may proceed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildConsentConfirmStep() {
    const checkLabels = [
      'I understand this is a research study and not a clinical service.',
      'I understand HATI is a self-help tool and not a therapy app.',
      'I understand what data will be collected and how it will be used.',
      'I know I can withdraw my participation at any time.',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B28D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You have read all sections. Please confirm the following statements to complete your consent.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1A1A2E),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Consent Statements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(4, (i) {
            return _ConsentCheckItem(
              label: checkLabels[i],
              checked: _consentChecks[i],
              onChanged: (v) => setState(() => _consentChecks[i] = v ?? false),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final List<String> stepTitles;
  final List<IconData> stepIcons;
  final VoidCallback onBack;

  const _Header({
    required this.stepIndex,
    required this.totalSteps,
    required this.stepTitles,
    required this.stepIcons,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B28D9),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button row
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Step ${stepIndex + 1} of $totalSteps',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current step title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      stepIcons[stepIndex],
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    stepTitles[stepIndex].replaceAll('\n', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bar with step dots
              _ProgressBar(stepIndex: stepIndex, totalSteps: totalSteps),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;

  const _ProgressBar({required this.stepIndex, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final leftStep = i ~/ 2;
          final filled = leftStep < stepIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: filled
                  ? Colors.white.withOpacity(0.7)
                  : Colors.white.withOpacity(0.2),
            ),
          );
        }
        final idx = i ~/ 2;
        final isDone = idx < stepIndex;
        final isActive = idx == stepIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isActive ? 28 : 20,
          height: isActive ? 28 : 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.white
                : isActive
                ? Colors.white
                : Colors.white.withOpacity(0.2),
            border: Border.all(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
              width: isActive ? 0 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: isDone
              ? Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: const Color(0xFF0B28D9),
                )
              : isActive
              ? Text(
                  '${idx + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B28D9),
                  ),
                )
              : Text(
                  '${idx + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
        );
      }),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int stepIndex;
  final bool canProceed;
  final VoidCallback onNext;
  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  const _BottomBar({
    required this.stepIndex,
    required this.canProceed,
    required this.onNext,
    required this.onAgree,
    required this.onDisagree,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = stepIndex == 4;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLastStep) ...[
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B28D9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: const Color(
                      0xFF0B28D9,
                    ).withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: onAgree,
                  child: const Text(
                    'I Agree & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: onDisagree,
                  child: const Text(
                    'I Do Not Agree',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B28D9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: const Color(
                      0xFF0B28D9,
                    ).withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: canProceed ? onNext : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        canProceed ? 'Next' : 'Scroll to continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (canProceed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ],
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

// ── Consent check item ────────────────────────────────────────────────────────

class _ConsentCheckItem extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  const _ConsentCheckItem({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFEEF1FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked
                ? const Color(0xFF0B28D9).withOpacity(0.5)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? const Color(0xFF0B28D9) : Colors.white,
                border: Border.all(
                  color: checked
                      ? const Color(0xFF0B28D9)
                      : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: checked
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFF64748B),
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Consent success dialog ────────────────────────────────────────────────────

class _ConsentSuccessDialog extends StatelessWidget {
  final VoidCallback onProceed;
  const _ConsentSuccessDialog({required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B28D9).withOpacity(0.1),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF0B28D9),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Consent Recorded',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B28D9),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your consent has been saved. You\'re ready to start setting up your HATI profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B28D9),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: onProceed,
                child: const Text(
                  'Set Up My Profile',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

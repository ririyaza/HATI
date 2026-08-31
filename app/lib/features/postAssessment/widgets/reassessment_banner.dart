import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/post_assessment_repository.dart';
import '../screen/post_assessment_intro_screen.dart';

/// Prompts the user to start their 2-week reassessment once it's due, as a
/// centered pop-up dialog matching the pre-test's `_DoThisLaterDialog`
/// styling (`spinAssessment/screen/spin_assessment_screen.dart`) — rather
/// than an inline dashboard card. Checked once per mount (i.e. once per
/// app session / dashboard visit); "Remind me tomorrow" snoozes it via
/// [PostAssessmentRepository.snoozeBannerOneDay], which needs no extra
/// local "shown today" state.
///
/// Renders nothing itself — the dialog is the UI. Kept as a widget (rather
/// than a plain function call from the dashboard) so it can own its own
/// mounted/one-shot guard independently of the dashboard's lifecycle.
class ReassessmentBanner extends StatefulWidget {
  const ReassessmentBanner({super.key});

  @override
  State<ReassessmentBanner> createState() => _ReassessmentBannerState();
}

class _ReassessmentBannerState extends State<ReassessmentBanner> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final due = await PostAssessmentRepository.isReassessmentDue(user.uid);
      if (!mounted || _handled || !due) return;
      _handled = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _ReassessmentDialog(),
      );
    } catch (_) {
      // Skip the prompt silently on failure; the profile screen's check-in
      // status card still surfaces this state on demand.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ReassessmentDialog extends StatelessWidget {
  const _ReassessmentDialog();

  static const _blue = Color(0xFF0B28D9);

  Future<void> _snooze(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await PostAssessmentRepository.snoozeBannerOneDay(user.uid);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: _blue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "It's time for your 2-week check-in",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'A quick 24-question reassessment to see how things are '
                'going since you started with HATI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PostAssessmentIntroScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Check-in',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _snooze(context),
                child: const Text(
                  'Remind me tomorrow',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
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

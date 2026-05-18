import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'assessment_complete_screen.dart';

class TriggersAndCopingScreen extends StatefulWidget {
  final int score;

  const TriggersAndCopingScreen({super.key, required this.score});

  @override
  State<TriggersAndCopingScreen> createState() =>
      _TriggersAndCopingScreenState();
}

class _TriggersAndCopingScreenState extends State<TriggersAndCopingScreen> {
  final _copingController = TextEditingController();
  bool _isSaving = false;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _copingController.addListener(_onCopingTextChanged);
    _redirectIfCopingAlreadySaved();
  }

  Future<void> _redirectIfCopingAlreadySaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final coping = doc.data()?['initialCopingMechanism'];
      if (coping is String && coping.trim().isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goToAssessmentComplete();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _copingController.removeListener(_onCopingTextChanged);
    _copingController.dispose();
    super.dispose();
  }

  void _onCopingTextChanged() {
    final hasInput = _copingController.text.trim().isNotEmpty;
    if (hasInput != _hasInput) {
      setState(() => _hasInput = hasInput);
    }
  }

  Future<void> _saveCoping(String coping) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      await userRef.collection('spinAssessments').doc('initial').set({
        'copingMechanism': coping,
        'copingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await userRef.set({
        'initialCopingMechanism': coping,
        'initialCopingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore write errors; user can still proceed.
    }
  }

  void _goToAssessmentComplete() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentCompleteScreen(score: widget.score),
      ),
    );
  }

  Future<void> _skip() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (!mounted) return;
    setState(() => _isSaving = false);
    _goToAssessmentComplete();
  }

  Future<void> _continue() async {
    if (_isSaving || !_hasInput) return;
    setState(() => _isSaving = true);

    await _saveCoping(_copingController.text.trim());

    if (!mounted) return;
    setState(() => _isSaving = false);
    _goToAssessmentComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Reflect on\nYour Experience',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Identifying what helps you cope can make your\nexperience more meaningful. You can skip or fill\nthese in later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'What helps you cope or feel better when you\'re stressed or anxious?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _copingController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'e.g. deep breathing, talking to a friend, going for a walk, journaling…',
                      hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black26, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSaving ? null : _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0056FF),
                        disabledBackgroundColor: const Color(
                          0xFF0056FF,
                        ).withOpacity(0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: (_hasInput && !_isSaving) ? _continue : null,
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

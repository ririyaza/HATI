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

class _TriggersAndCopingScreenState extends State<TriggersAndCopingScreen>
    with SingleTickerProviderStateMixin {
  final _copingController = TextEditingController();
  bool _isSaving = false;
  bool _hasInput = false;

  final _selectedChips = <String>{};

  static const _copingChips = [
    ('Deep breathing', Icons.air_rounded),
    ('Going for a walk', Icons.directions_walk_rounded),
    ('Listening to music', Icons.headphones_rounded),
    ('Journaling', Icons.edit_note_rounded),
    ('Talking to a friend', Icons.chat_bubble_outline_rounded),
    ('Meditation', Icons.self_improvement_rounded),
    ('Exercise', Icons.fitness_center_rounded),
    ('Taking a break', Icons.coffee_rounded),
  ];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _copingController.addListener(_onCopingTextChanged);
    _redirectIfCopingAlreadySaved();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
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
    _animCtrl.dispose();
    super.dispose();
  }

  void _onCopingTextChanged() {
    final hasInput =
        _copingController.text.trim().isNotEmpty || _selectedChips.isNotEmpty;
    if (hasInput != _hasInput) setState(() => _hasInput = hasInput);
  }

  void _toggleChip(String label) {
    setState(() {
      if (_selectedChips.contains(label)) {
        _selectedChips.remove(label);
      } else {
        _selectedChips.add(label);
      }
      _hasInput = _selectedChips.isNotEmpty ||
          _copingController.text.trim().isNotEmpty;
    });
  }

  String _buildCopingText() {
    final chips = _selectedChips.toList();
    final custom = _copingController.text.trim();
    if (chips.isNotEmpty && custom.isNotEmpty) {
      return '${chips.join(', ')}; $custom';
    } else if (chips.isNotEmpty) {
      return chips.join(', ');
    }
    return custom;
  }

  Future<void> _saveCoping(String coping) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      await userRef.collection('spinAssessments').doc('initial').set({
        'copingMechanism': coping,
        'copingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await userRef.set({
        'initialCopingMechanism': coping,
        'initialCopingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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
    await _saveCoping(_buildCopingText());
    if (!mounted) return;
    setState(() => _isSaving = false);
    _goToAssessmentComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B28D9),
      // ── Keyboard avoid: body scrolls up, bottom bar stays pinned ──
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Blue header (no transform tricks) ────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HATI',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Coping Strategies',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'What helps you feel better when you\'re stressed or anxious?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── White card body — fills rest of screen cleanly ───────────
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                color: Colors.white,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(24, 28, 24, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Quick select ──────────────────────
                                const _FieldLabel(
                                  icon: Icons.bolt_rounded,
                                  label: 'Quick Select',
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _copingChips.map((chip) {
                                    final (label, icon) = chip;
                                    final selected =
                                        _selectedChips.contains(label);
                                    return _CopingChip(
                                      label: label,
                                      icon: icon,
                                      selected: selected,
                                      onTap: () => _toggleChip(label),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 28),

                                // ── Divider ───────────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.black.withOpacity(0.08),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        'or describe your own',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.black.withOpacity(0.4),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.black.withOpacity(0.08),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // ── Custom text input ─────────────────
                                const _FieldLabel(
                                  icon: Icons.edit_rounded,
                                  label: 'In Your Own Words',
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _copingController,
                                  maxLines: 4,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A2E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'e.g. going for a walk, calling a friend…',
                                    hintStyle: TextStyle(
                                      color: Colors.black.withOpacity(0.3),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8F9FF),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E6FF),
                                        width: 1.2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E6FF),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0B28D9),
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ── Info note ─────────────────────────
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF1FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: const Color(0xFF0B28D9)
                                            .withOpacity(0.7),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'This helps Hati suggest personalised strategies during your sessions. You can update this anytime.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: const Color(0xFF0B28D9)
                                                .withOpacity(0.8),
                                            height: 1.45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Extra bottom padding so content clears
                                // the action bar when scrolled to end
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),

                        // ── Bottom action bar — pinned, never clipped ──
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withOpacity(0.06),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 12, 24, 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.black26,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(26),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      onPressed: _isSaving ? null : _skip,
                                      child: const Text(
                                        'Skip for now',
                                        style: TextStyle(
                                          fontSize: 15,
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
                                        backgroundColor:
                                            const Color(0xFF0B28D9),
                                        disabledBackgroundColor:
                                            const Color(0xFF0B28D9)
                                                .withOpacity(0.35),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(26),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                      onPressed: (_hasInput && !_isSaving)
                                          ? _continue
                                          : null,
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Save & Continue',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FieldLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0B28D9)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}

// ── Coping chip ───────────────────────────────────────────────────────────────

class _CopingChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CopingChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0B28D9)
              : const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF0B28D9)
                : const Color(0xFFE2E6FF),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? Colors.white
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
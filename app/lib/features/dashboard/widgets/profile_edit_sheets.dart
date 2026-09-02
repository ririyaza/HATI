import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Bottom sheets for editing profile fields that can be left unset (or
/// changed) after onboarding: name & pronouns, profile picture, goal, and
/// coping preferences. Each writes straight to the `users/{uid}` doc that
/// `DashboardUserData`'s stream already listens to, so the Profile screen
/// updates itself — no local state to thread back.
const _blue = Color(0xFF0B28D9);

// ── Avatar picker ────────────────────────────────────────────────────────

/// Same 4 built-in avatars offered during onboarding
/// (`onboarding/profile_setup_screen.dart`). Duplicated here rather than
/// shared, matching this codebase's convention of small per-screen private
/// widgets over a shared design system — kept in sync manually if the
/// avatar set ever changes.
const _defaultProfileAvatars = [
  'assets/images/defaultProfile/IMG_0370.PNG',
  'assets/images/defaultProfile/IMG_0371.PNG',
  'assets/images/defaultProfile/IMG_0372.PNG',
  'assets/images/defaultProfile/IMG_0373.PNG',
];

Future<void> showAvatarPickerSheet(
  BuildContext context, {
  required String uid,
  required String? currentAssetPath,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) =>
        _AvatarPickerSheet(currentAssetPath: currentAssetPath),
  );
  if (selected == null) return;

  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'profilePicAssetPath': selected,
      'profilePicSource': 'defaultProfile',
      'profilePicUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (_) {
    if (context.mounted) _showSaveError(context);
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.currentAssetPath});

  final String? currentAssetPath;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose an Avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Pick one of HATI's default profile pictures.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _defaultProfileAvatars.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final avatar = _defaultProfileAvatars[index];
                final isSelected = avatar == currentAssetPath;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, avatar),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? _blue : const Color(0xFFE2E6FF),
                    ),
                    child: ClipOval(
                      child: Image.asset(avatar, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Name & pronouns editor ────────────────────────────────────────────────

/// Same pronoun options offered during onboarding
/// (`onboarding/profile_setup_screen.dart`), duplicated here for the same
/// reason as the avatar list above.
const _pronounOptions = [
  ('She/Her', Icons.female_rounded),
  ('He/Him', Icons.male_rounded),
  ('They/Them', Icons.people_alt_outlined),
  ('Prefer not to say', Icons.remove_rounded),
];

Future<void> showEditNameAndPronounsSheet(
  BuildContext context, {
  required String uid,
  required String currentName,
  required String currentPronouns,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _EditNamePronounsSheet(
      uid: uid,
      currentName: currentName,
      currentPronouns: currentPronouns,
    ),
  );
}

class _EditNamePronounsSheet extends StatefulWidget {
  const _EditNamePronounsSheet({
    required this.uid,
    required this.currentName,
    required this.currentPronouns,
  });

  final String uid;
  final String currentName;
  final String currentPronouns;

  @override
  State<_EditNamePronounsSheet> createState() =>
      _EditNamePronounsSheetState();
}

class _EditNamePronounsSheetState extends State<_EditNamePronounsSheet> {
  late final _nameController = TextEditingController(text: widget.currentName);
  late String? _selectedPronouns = widget.currentPronouns.isEmpty
      ? null
      : widget.currentPronouns;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set(
        {
          'displayName': name,
          'nickname': name,
          'pronouns': _selectedPronouns,
        },
        SetOptions(merge: true),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showSaveError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              const Text(
                'Name & Pronouns',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update how HATI addresses you.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14.5,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _blue, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pronouns',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _pronounOptions.map((opt) {
                  final (label, icon) = opt;
                  final selected = _selectedPronouns == label;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPronouns = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _blue : const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected ? _blue : const Color(0xFFE2E6FF),
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
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
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
    );
  }
}

// ── Goal editor ───────────────────────────────────────────────────────────

Future<void> showEditGoalSheet(
  BuildContext context, {
  required String uid,
  required String currentGoal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _EditGoalSheet(uid: uid, currentGoal: currentGoal),
  );
}

class _EditGoalSheet extends StatefulWidget {
  const _EditGoalSheet({required this.uid, required this.currentGoal});

  final String uid;
  final String currentGoal;

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  late final _controller = TextEditingController(text: widget.currentGoal);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({'goal': _controller.text.trim()}, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showSaveError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              const Text(
                'My Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'What would you like to get out of HATI?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. feel more comfortable speaking in class',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 14.5,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _blue, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Goal',
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
    );
  }
}

// ── Coping preferences editor ────────────────────────────────────────────

/// Same quick-select set offered during onboarding
/// (`spinAssessment/screen/triggers_and_coping_screen.dart`), duplicated
/// here for the same reason as the avatar list above.
const _copingChips = [
  ('Deep breathing', Icons.air_rounded),
  ('Going for a walk', Icons.directions_walk_rounded),
  ('Listening to music', Icons.headphones_rounded),
  ('Journaling', Icons.edit_note_rounded),
  ('Talking to a friend', Icons.chat_bubble_outline_rounded),
  ('Meditation', Icons.self_improvement_rounded),
  ('Exercise', Icons.fitness_center_rounded),
  ('Taking a break', Icons.coffee_rounded),
];

Future<void> showEditCopingSheet(
  BuildContext context, {
  required String uid,
  required String currentText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _EditCopingSheet(uid: uid, currentText: currentText),
  );
}

class _EditCopingSheet extends StatefulWidget {
  const _EditCopingSheet({required this.uid, required this.currentText});

  final String uid;
  final String currentText;

  @override
  State<_EditCopingSheet> createState() => _EditCopingSheetState();
}

class _EditCopingSheetState extends State<_EditCopingSheet> {
  late final _customController = TextEditingController();
  final _selectedChips = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final knownLabels = {for (final c in _copingChips) c.$1};
    final leftovers = <String>[];
    for (final part in widget.currentText.split(RegExp(r'[,;]'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final match = knownLabels.firstWhere(
        (label) => label.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        _selectedChips.add(match);
      } else {
        leftovers.add(trimmed);
      }
    }
    _customController.text = leftovers.join(', ');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _buildCopingText() {
    final chips = _selectedChips.toList();
    final custom = _customController.text.trim();
    if (chips.isNotEmpty && custom.isNotEmpty) {
      return '${chips.join(', ')}; $custom';
    } else if (chips.isNotEmpty) {
      return chips.join(', ');
    }
    return custom;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final coping = _buildCopingText();
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);
    try {
      await userRef.collection('spinAssessments').doc('initial').set({
        'copingMechanism': coping,
        'copingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await userRef.set({
        'initialCopingMechanism': coping,
        'initialCopingRecordedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showSaveError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 18),
                const Text(
                  'Coping Preferences',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "What helps you feel better when you're stressed or anxious?",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _copingChips.map((chip) {
                    final (label, icon) = chip;
                    final selected = _selectedChips.contains(label);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedChips.remove(label);
                        } else {
                          _selectedChips.add(label);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _blue : const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: selected ? _blue : const Color(0xFFE2E6FF),
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
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'In your own words',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customController,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. calling a friend, drawing…',
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E6FF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _blue, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Preferences',
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
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

void _showSaveError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Something went wrong. Please try again.')),
  );
}

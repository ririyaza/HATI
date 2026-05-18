import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../spinAssessment/screen/spin_assessment_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _goalController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _selectedPronouns;
  XFile? _selectedAvatar;
  Uint8List? _selectedAvatarBytes;
  bool _isSaving = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _nicknameController.dispose();
    _goalController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not logged in.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profilePicUrl = await _uploadProfilePicToStorage(user.uid);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': _nicknameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'pronouns': _selectedPronouns,
        'goal': _goalController.text.trim(),
        if (profilePicUrl != null) ...{
          'profilePicUrl': profilePicUrl.url,
          'profilePicStoragePath': profilePicUrl.storagePath,
          'profilePicUpdatedAt': FieldValue.serverTimestamp(),
        },
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (profilePicUrl != null) {
        await user.updatePhotoURL(profilePicUrl.url);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SpinAssessmentScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'An error occurred while saving your profile.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedAvatar = picked;
      _selectedAvatarBytes = bytes;
    });
  }

  Future<_ProfilePicUpload?> _uploadProfilePicToStorage(String uid) async {
    final avatar = _selectedAvatar;
    final bytes = _selectedAvatarBytes;
    if (avatar == null || bytes == null) return null;

    final extension = avatar.name.split('.').last.toLowerCase();
    final safeExtension = extension == 'png' ? 'png' : 'jpg';
    final storagePath = 'users/$uid/profile/avatar.$safeExtension';
    final contentType = safeExtension == 'png' ? 'image/png' : 'image/jpeg';
    final metadata = SettableMetadata(contentType: contentType);
    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putData(bytes, metadata);

    final downloadUrl = await ref.getDownloadURL();
    return _ProfilePicUpload(url: downloadUrl, storagePath: storagePath);
  }

  static const _pronounOptions = [
    ('She/Her', Icons.female_rounded),
    ('He/Him', Icons.male_rounded),
    ('They/Them', Icons.people_alt_outlined),
    ('Prefer not to say', Icons.remove_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B28D9),
      body: Column(
        children: [
          // ── Blue header ──────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                  const SizedBox(height: 14),
                  const Text(
                    'Set Up Your Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tell us a little about yourself so Hati\ncan personalise your experience.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  // Space for the avatar to straddle the seam
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),

          // ── White card ───────────────────────────────────────────────
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Scrollable white body
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        // Top padding reserves space below the floating avatar
                        padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Nickname ─────────────────────────
                              const _FieldLabel(
                                icon: Icons.badge_outlined,
                                label: 'Nickname',
                                required: true,
                              ),
                              const SizedBox(height: 8),
                              _StyledTextField(
                                controller: _nicknameController,
                                hint: 'What should we call you?',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Please enter a nickname'
                                        : null,
                              ),
                              const SizedBox(height: 24),

                              // ── Pronouns ──────────────────────────
                              const _FieldLabel(
                                icon: Icons.person_outline_rounded,
                                label: 'Pronouns',
                              ),
                              const SizedBox(height: 12),
                              _PronounsSelector(
                                options: _pronounOptions,
                                selected: _selectedPronouns,
                                onSelect: (v) =>
                                    setState(() => _selectedPronouns = v),
                              ),
                              const SizedBox(height: 24),

                              // ── Goal ──────────────────────────────
                              const _FieldLabel(
                                icon: Icons.flag_outlined,
                                label: 'My Goal',
                              ),
                              const SizedBox(height: 8),
                              _StyledTextField(
                                controller: _goalController,
                                hint: 'What would you like to get out of HATI? (optional)',
                                maxLines: 3,
                              ),

                              const SizedBox(height: 36),

                              // ── Save button ───────────────────────
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B28D9),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        const Color(0xFF0B28D9).withOpacity(0.4),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27),
                                    ),
                                  ),
                                  onPressed: _isSaving ? null : _saveProfile,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save & Continue',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Text(
                                  'You can update your profile anytime from Settings.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withOpacity(0.4),
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

                // ── Avatar — straddling blue header / white card ──────
                Positioned(
                  top: -52,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _AvatarPicker(
                      imageBytes: _selectedAvatarBytes,
                      onTap: _isSaving ? null : _pickAvatar,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePicUpload {
  const _ProfilePicUpload({required this.url, required this.storagePath});

  final String url;
  final String storagePath;
}

// ── Avatar picker ─────────────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.imageBytes, required this.onTap});

  final Uint8List? imageBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White ring pops against both the blue header and white card
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B28D9).withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFFEEF1FF),
                child: imageBytes == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: const Color(0xFF0B28D9).withOpacity(0.35),
                      )
                    : Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          // Camera badge
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onTap == null
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0B28D9),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 15,
                color: Colors.white,
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
  final bool required;

  const _FieldLabel({
    required this.icon,
    required this.label,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF0B28D9).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF0B28D9)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFD9250B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Styled text field ─────────────────────────────────────────────────────────

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A2E),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.3),
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E6FF), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E6FF), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0B28D9), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9250B), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9250B), width: 1.8),
        ),
      ),
    );
  }
}

// ── Pronouns selector ─────────────────────────────────────────────────────────

class _PronounsSelector extends StatelessWidget {
  final List<(String, IconData)> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _PronounsSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final (label, icon) = opt;
        final isSelected = selected == label;
        return GestureDetector(
          onTap: () => onSelect(label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0B28D9)
                  : const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0B28D9)
                    : const Color(0xFFE2E6FF),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0B28D9).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
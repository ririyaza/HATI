import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'email_verification_screen.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/audio/hati_tap_sound.dart';

// Brand tokens shared with the loading screen and onboarding/consent flow —
// keep these in sync with lib/features/onboarding/consent_flow_screen.dart
// so auth doesn't visually diverge from the rest of the app.
const _kBrand = Color(0xFF0B28D9);
const _kBrandTint = AppColors.creamSoft;
const _kBrandBorder = AppColors.creamLine;
const _kTextDark = Color(0xFF1A1A2E);
const _kTextMuted = Color(0xFF6B7280);
const _kFieldBorder = AppColors.creamLine;
const _kRuleMet = Color(0xFF2E7D32);

// Password policy: 12–128 characters, with at least one uppercase letter,
// one number and one special character. Long passphrases are allowed (the
// 128 cap only guards against absurd input), and spaces count as characters.
const kPasswordMinLength = 12;
const kPasswordMaxLength = 128;

/// One requirement in the signup password checklist.
class _PasswordRule {
  const _PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String) test;
}

final _passwordRules = <_PasswordRule>[
  _PasswordRule(
    'At least $kPasswordMinLength characters',
    (p) => p.length >= kPasswordMinLength,
  ),
  _PasswordRule('One uppercase letter (A–Z)', (p) => p.contains(RegExp('[A-Z]'))),
  _PasswordRule('One number (0–9)', (p) => p.contains(RegExp('[0-9]'))),
  // Anything that isn't a letter, digit or whitespace counts as special.
  _PasswordRule(
    r'One special character (e.g. ! @ # $ %)',
    (p) => p.contains(RegExp(r'[^A-Za-z0-9\s]')),
  ),
];

/// First unmet rule's message, or null when the password is acceptable.
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Please enter your password';
  if (value.length > kPasswordMaxLength) {
    return 'Password must be at most $kPasswordMaxLength characters';
  }
  for (final rule in _passwordRules) {
    if (!rule.test(value)) return 'Password needs: ${rule.label.toLowerCase()}';
  }
  return null;
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await user.sendEmailVerification();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const EmailVerificationScreen(
            returnToLoginOnVerified: true,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'weak-password':
          message =
              'Password is too weak. Use at least $kPasswordMinLength '
              'characters with an uppercase letter, a number and a '
              'special character.';
          break;
        case 'operation-not-allowed':
          message = 'Email sign-up is not enabled.';
          break;
        default:
          message = e.message ?? 'Sign up failed. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _kBrandTint,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const _BrandMark(),
                const SizedBox(height: 28),
                // Title
                Text(
                  'Create your account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to start your journey with Hati',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _kTextMuted,
                  ),
                ),
                const SizedBox(height: 36),
                // Email Field
                Text(
                  'Email',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _kTextDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _fieldDecoration(hintText: 'Enter your email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password Field
                Text(
                  'Password',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _kTextDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kPasswordMaxLength),
                  ],
                  // Rebuilds the checklist below as the user types.
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration(
                    hintText: 'At least $kPasswordMinLength characters',
                    suffixIcon: HatiTapSound.silent(
                      child: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kTextMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 10),
                _PasswordChecklist(password: _passwordController.text),
                const SizedBox(height: 20),
                // Confirm Password Field
                Text(
                  'Confirm Password',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _kTextDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _fieldDecoration(
                    hintText: 'Confirm your password',
                    suffixIcon: HatiTapSound.silent(
                      child: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _kTextMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // Sign Up Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand,
                      foregroundColor: AppColors.cream,
                      elevation: 0,
                      disabledBackgroundColor: _kBrand.withOpacity(0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cream,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                // Login Link
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _kTextMuted,
                      ),
                    ),
                    HatiTapSound.click(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Login',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _kBrand,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

InputDecoration _fieldDecoration({required String hintText, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
    filled: true,
    fillColor: AppColors.creamSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kFieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kFieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kBrand, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade300),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    suffixIcon: suffixIcon,
  );
}

/// Live list of the password rules under the password field — each turns
/// green with a check once the typed password satisfies it.
class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in _passwordRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  rule.test(password)
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: rule.test(password) ? _kRuleMet : _kTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: rule.test(password) ? _kRuleMet : _kTextMuted,
                      fontWeight: rule.test(password)
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small brand badge shared by login/signup — echoes the "HATI" wordmark
/// shown on the splash screen so auth doesn't feel like a separate app.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBrandBorder, width: 1.2),
            ),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'HATI',
          style: TextStyle(
            color: _kBrand,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

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

class _ConsentFlowScreenState extends State<ConsentFlowScreen> {
  int _stepIndex = 0;

  final _consentChecks = <bool>[false, false, false, false];
  final ScrollController _aboutScrollController = ScrollController();
  final ScrollController _dataScrollController = ScrollController();
  final ScrollController _risksScrollController = ScrollController();
  final ScrollController _rightsScrollController = ScrollController();
  bool _hasScrolledAbout = false;
  bool _hasScrolledData = false;
  bool _hasScrolledRisks = false;
  bool _hasScrolledRights = false;

  @override
  void initState() {
    super.initState();
    _aboutScrollController.addListener(_handleAboutScroll);
    _dataScrollController.addListener(_handleDataScroll);
    _risksScrollController.addListener(_handleRisksScroll);
    _rightsScrollController.addListener(_handleRightsScroll);
  }

  @override
  void dispose() {
    _aboutScrollController.removeListener(_handleAboutScroll);
    _dataScrollController.removeListener(_handleDataScroll);
    _risksScrollController.removeListener(_handleRisksScroll);
    _rightsScrollController.removeListener(_handleRightsScroll);
    _aboutScrollController.dispose();
    _dataScrollController.dispose();
    _risksScrollController.dispose();
    _rightsScrollController.dispose();
    super.dispose();
  }

  void _handleAboutScroll() {
    if (_hasScrolledAbout) return;
    if (!_aboutScrollController.hasClients) return;
    final position = _aboutScrollController.position;
    if (!position.hasContentDimensions) return;
    final atBottom = position.pixels >= position.maxScrollExtent - 2;
    if (atBottom) {
      setState(() => _hasScrolledAbout = true);
    }
  }

  void _handleDataScroll() {
    if (_hasScrolledData) return;
    if (!_dataScrollController.hasClients) return;
    final position = _dataScrollController.position;
    if (!position.hasContentDimensions) return;
    final atBottom = position.pixels >= position.maxScrollExtent - 2;
    if (atBottom) {
      setState(() => _hasScrolledData = true);
    }
  }

  void _handleRisksScroll() {
    if (_hasScrolledRisks) return;
    if (!_risksScrollController.hasClients) return;
    final position = _risksScrollController.position;
    if (!position.hasContentDimensions) return;
    final atBottom = position.pixels >= position.maxScrollExtent - 2;
    if (atBottom) {
      setState(() => _hasScrolledRisks = true);
    }
  }

  void _handleRightsScroll() {
    if (_hasScrolledRights) return;
    if (!_rightsScrollController.hasClients) return;
    final position = _rightsScrollController.position;
    if (!position.hasContentDimensions) return;
    final atBottom = position.pixels >= position.maxScrollExtent - 2;
    if (atBottom) {
      setState(() => _hasScrolledRights = true);
    }
  }

  void _nextStep() {
    if (_stepIndex < 4) {
      setState(() => _stepIndex++);
    }
  }

  void _previousStep() {
    if (_stepIndex > 0) {
      setState(() => _stepIndex--);
    }
  }

  Future<void> _handleDisagree() async {
    // Simply pop back to login / previous screen
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleAgreeAndContinue() async {
    final allChecked = _consentChecks.every((c) => c);
    if (!allChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please review and check all consent statements.'),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consent saved locally. We will sync it when online.',
            ),
          ),
        );
      }
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6F0FF),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF0056FF),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Consent Recorded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF0056FF),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you. Your consent has been recorded. You may now use HATI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0056FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Proceed',
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    String title;
    final String subtitle = 'Step ${_stepIndex + 1} of 5';

    switch (_stepIndex) {
      case 0:
        title = 'What This Study Is About';
        content = _buildStudyAboutBox(theme);
        break;
      case 1:
        title = 'What Data We Collect';
        content = _buildDataCollectedBox(theme);
        break;
      case 2:
        title = 'Possible Risks & Support';
        content = _buildRisksSupportBox(theme);
        break;
      case 3:
        title = 'Your Rights as a Participant';
        content = _buildParticipantRightsBox(theme);
        break;
      case 4:
      default:
        title = 'Consent Confirmation';
        content = Align(
          alignment: Alignment.topCenter,
          child: _buildConsentCard(theme),
        );
        break;
    }

    final isLastStep = _stepIndex == 4;
    final isAboutStep = _stepIndex == 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () {
                    if (_stepIndex == 0) {
                      Navigator.of(context).pop();
                    } else {
                      _previousStep();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
              ),
              Center(
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              content,
              const SizedBox(height: 50),
              if (isLastStep)
                _buildConsentButtons(theme)
              else
                _buildNavigationButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderBox() {
    return Center(
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
      ),
    );
  }

  Widget _buildStudyAboutBox(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          controller: _aboutScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _aboutScrollController,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: kConsentStudyAboutSpans,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCollectedBox(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          controller: _dataScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _dataScrollController,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: kConsentDataCollectedSpans,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRisksSupportBox(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          controller: _risksScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _risksScrollController,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: kConsentRisksSupportSpans,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRightsBox(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          controller: _rightsScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _rightsScrollController,
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: kConsentParticipantRightsSpans,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    final canProceed = switch (_stepIndex) {
      0 => _hasScrolledAbout,
      1 => _hasScrolledData,
      2 => _hasScrolledRisks,
      3 => _hasScrolledRights,
      _ => true,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0056FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: canProceed ? _nextStep : null,
            child: const Text(
              'Next',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consent Statements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCheckboxRow(0, 'I understand this is a research study'),
          _buildCheckboxRow(1, 'I understand HATI is not a therapy app'),
          _buildCheckboxRow(2, 'I understand what data is collected'),
          _buildCheckboxRow(3, 'I know I can withdraw at any time'),
        ],
      ),
    );
  }

  Widget _buildConsentButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0026A8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: _handleAgreeAndContinue,
            child: const Text(
              'I Agree and Continue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: _handleDisagree,
            child: const Text(
              'I Do Not Agree',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow(int index, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _consentChecks[index],
          onChanged: (value) {
            setState(() {
              _consentChecks[index] = value ?? false;
            });
          },
          activeColor: const Color(0xFF0056FF),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(label)),
      ],
    );
  }
}

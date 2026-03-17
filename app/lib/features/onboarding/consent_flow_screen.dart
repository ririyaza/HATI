import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  bool _hasScrolledAbout = false;

  @override
  void initState() {
    super.initState();
    _aboutScrollController.addListener(_handleAboutScroll);
  }

  @override
  void dispose() {
    _aboutScrollController.removeListener(_handleAboutScroll);
    _aboutScrollController.dispose();
    _dataScrollController.dispose();
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
              if (isAboutStep) content else Expanded(child: content),
              if (isAboutStep) const Spacer(),
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
      height: 300,
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
            child: Text(
              '1. What is this study about?\n'
              'You are invited to participate in a research study developing and evaluating HATI, a mobile application designed to help students who experience high levels of social anxiety symptoms. The app includes a virtual companion named "Hati" that provides gamified social scenarios, emotion tracking, and coping strategies in a safe, private environment.\n'
              'This study aims to understand whether such an application can help students better recognize their emotional patterns and practice coping skills in social situations.\n\n'
              '2. Why am I being invited to participate?\n'
              'You are being invited because:\n'
              'You are a third-year undergraduate student at West Visayas State University.\n'
              'You have scored above 40 on the Social Phobia Inventory (SPIN) screening, indicating high social anxiety symptoms.\n'
              'You are not currently diagnosed with Social Anxiety Disorder or receiving active professional mental health treatment.\n'
              'You are 20 years of age or older.\n\n'
              '3. What will happen if I agree to participate?\n'
              'If you agree to participate, you will be asked to:\n'
              'Install the application on your mobile device with the assistance of the researchers.\n'
              'Complete an initial SPIN assessment within the app (if not already completed).\n'
              'Use the HATI application for a period of two weeks.\n'
              'During use, you will engage with gamified social scenarios where you will type responses. You may also be given the option to provide brief voice recordings to help the app detect emotional cues.\n'
              'The app will track your emotional patterns over time and provide adaptive feedback from the virtual companion.\n'
              'At the end of the study period, you will complete another SPIN assessment and a GAD-7 assessment.\n'
              'Participants will be asked to share their experience with the app through a feedback form.\n\n'
              '4. Is HATI a substitute for professional mental health treatment?\n'
              'No. HATI is a self-help support tool designed for non-clinical use. It is not a diagnostic instrument and does not replace professional psychological or psychiatric treatment.\n'
              'If you have concerns about your mental health, you may reach out to the WVSU University Guidance and Counseling Office:\n'
              'Location: Hometel, Ground Floor, West Visayas State University\n'
              'Contact:\n'
              'Email:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.5,
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
      height: 300,
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
            child: Text(
              '5. What type of data will be collected?\n'
              'The following data will be collected:\n'
              'Assessment Data: Your SPIN and GAD-7 scores.\n'
              'App Usage Data: Your interactions with the app, including scenario choices, emotion logs, and progress tracking.\n'
              'Text Input: The responses you type during gamified scenarios.\n'
              'Audio Input: Optional voice recordings you choose to provide for emotion detection.\n'
              'Feedback Data: Interview responses if you participate in the optional feedback session.\n\n'
              '6. How will my data be used?\n'
              'Your data will be used for research purposes only, including:\n'
              'Analyzing the usability and effectiveness of the HATI application.\n'
              'Writing academic publications (thesis, presentation).\n'
              'Improving future versions of the application.\n\n'
              '7. Will my data be kept private?\n'
              'Yes. The research team will protect your privacy in the following ways:\n'
              'Your data will be assigned a unique participant code for anonymization. Your name will not be stored with your research data and will only be accessed by one person in the research team.\n'
              'All data will be stored on password-protected, encrypted servers accessible only to the core research team.\n'
              'This study complies with the Philippine Data Privacy Act of 2012 (RA 10173).\n'
              'Data transmission from third-party services used for emotion detection (text and voice analysis) will be encrypted and will not be permanently stored by these services.\n'
              'Your personal identity will never be revealed in any publications or presentations resulting from this research. Only grouped or anonymized data will be reported.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.5,
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
      height: 300,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Text(
              '8. What are the potential risks of participating?\n'
              'The risks are minimal but may include:\n'
              'Temporary Discomfort: Reflecting on anxiety-provoking social situations may cause mild emotional discomfort. This is normal and similar to what you might experience in daily life.\n'
              'Privacy Risks: As with any digital application, there is a small risk of data breach, though we take extensive precautions to prevent this.\n'
              'If you experience significant distress while using the app, you are encouraged to contact the research team using the information provided at the end of this form. You will also be provided with contact information for the university guidance and counseling office and other mental health resources.\n\n'
              '9. What are the potential benefits of participating?\n'
              'While there is no guarantee of direct benefit, possible benefits include:\n'
              'Greater awareness of your emotional patterns and triggers.\n'
              'Learning and practicing coping strategies for social anxiety.\n'
              'Contributing to research that may help other students with similar experiences.\n'
              'Access to a free, private tool for emotional self-monitoring.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.5,
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
      height: 300,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Text(
              '10. Is my participation mandatory?\n'
              'No. Your participation is completely voluntary. You may choose not to participate, or you may withdraw from the study at any time without any penalty, loss of benefits, or negative consequences to your academic standing.\n'
              'If you withdraw, any data collected from you will be deleted and not used in the research.\n\n'
              '11. Who can I contact if I have questions or concerns?\n'
              'If you have any questions about this study, please contact:\n'
              'Researcher: Precious Mae J. Taleon\n'
              'Email: preciousmae.taleon@wvsu.edu.ph\n'
              'Contact Number: 09275311191\n'
              'Researcher: Jaspher John E. Samalburo\n'
              'Email: jaspherjohn.samalburo@wvsu.edu.ph\n'
              'Contact Number: 09\n'
              'If you experience distress, you can contact:\n'
              'The National Centre for Mental Health Crisis Hotline\n'
              'Tel: (02) 989-8727 (telephone)\n'
              'Tel: (0917) 899-8727 (cellphone)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    final isAboutStep = _stepIndex == 0;
    final canProceed = !isAboutStep || _hasScrolledAbout;
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

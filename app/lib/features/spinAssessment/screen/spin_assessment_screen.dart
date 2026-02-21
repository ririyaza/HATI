import 'package:flutter/material.dart';
import '../data/spin_questions.dart';
import 'assessment_complete_screen.dart';

class SpinAssessmentScreen extends StatefulWidget {
  const SpinAssessmentScreen({super.key});

  @override
  State<SpinAssessmentScreen> createState() => _SpinAssessmentScreenState();
}

class _SpinAssessmentScreenState extends State<SpinAssessmentScreen> {
  int currentIndex = 0;

  final options = [
    "Not at all",
    "A little bit",
    "Somewhat",
    "Very much",
    "Extremely",
  ];

  void nextQuestion() {
    if (currentIndex < spinQuestions.length - 1) {
      setState(() => currentIndex++);
    } else {
      int totalScore = spinQuestions.fold(
        0,
        (sum, q) => sum + (q.selectedScore ?? 0),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentCompleteScreen(score: totalScore),
        ),
      );
    }
  }

  void previousQuestion() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = spinQuestions[currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Understanding\nSocial Situations",
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "A short check-in to help personalize your experience",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Instruction",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "For each statement, select how much it describes your "
                "experience during the past week.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black.withOpacity(0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${currentIndex + 1} of ${spinQuestions.length}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question.question,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(options.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: const Color(0xFF0056FF),
                              title: Text(
                                options[index],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                              value: question.selectedScore == index,
                              onChanged: (_) {
                                setState(() {
                                  question.selectedScore = index;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                      onPressed: previousQuestion,
                      child: const Text(
                        "Back",
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
                        ).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: question.selectedScore == null
                          ? null
                          : nextQuestion,
                      child: const Text(
                        "Next",
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
              const SizedBox(height: 16),
              Text(
                "This is not a diagnostic test. Your responses are used\n"
                "only for research and personalization.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black.withOpacity(0.5),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

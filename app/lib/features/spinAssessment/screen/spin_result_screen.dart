import 'package:flutter/material.dart';

class SpinResultScreen extends StatelessWidget {
  final int score;

  const SpinResultScreen({super.key, required this.score});

  String interpretation(int score) {
    if (score <= 19) {
      return "Low level of social anxiety / No social phobia";
    } else if (score <= 30) {
      return "Mild social phobia";
    } else if (score <= 40) {
      return "Moderate social phobia";
    } else if (score <= 50) {
      return "Severe social phobia";
    } else {
      return "Very severe social phobia";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SPIN Result")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Your Score: $score",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                interpretation(score),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SpinResultScreen extends StatelessWidget {
  final int score;

  const SpinResultScreen({super.key, required this.score});

  String interpretation(int score) {
    if (score <= 19) {
      return "You report very few difficulties in social situations.";
    } else if (score <= 30) {
      return "You report some challenges in social situations.";
    } else if (score <= 40) {
      return "You report moderate challenges in social situations.";
    } else if (score <= 50) {
      return "You report significant challenges in social situations.";
    } else {
      return "You report very significant challenges in social situations.";
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

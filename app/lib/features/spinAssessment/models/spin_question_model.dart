class SpinQuestion {
  final String question;
  final String theme;
  int? selectedScore; // 0–4

  SpinQuestion({required this.question, required this.theme, this.selectedScore});
}

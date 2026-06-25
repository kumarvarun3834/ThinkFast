import 'package:flutter/material.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

class ManageQuizButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ManageQuizButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return QuizActionButton(
      text: "Manage Quiz",
      onPressed: onPressed,
      icon: Icons.settings_outlined,
    );
  }
}

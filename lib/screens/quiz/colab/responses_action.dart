import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class ResponsesAction extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final bool isAdmin;
  final bool hasPerm;

  const ResponsesAction({
    super.key,
    required this.quizData,
    required this.isAdmin,
    required this.hasPerm,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: "View Responses",
      icon: Icons.analytics_outlined,
      enabled: hasPerm,
      globalFlag: 'management_features',
      isAdmin: isAdmin,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          "/Quiz Responses",
          arguments: {
            'quizId': quizData['id'],
            'quizTitle': quizData['title'] ?? 'Quiz',
          },
        );
      },
    );
  }
}

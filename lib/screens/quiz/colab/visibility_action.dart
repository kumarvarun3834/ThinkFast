import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class VisibilityAction extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final bool isAdmin;
  final bool hasPerm;
  final VoidCallback onTap;

  const VisibilityAction({
    super.key,
    required this.quizData,
    required this.isAdmin,
    required this.hasPerm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: quizData['visibility'] == 'public' ? "Make Private" : "Make Public",
      icon: quizData['visibility'] == 'public' ? Icons.lock_outline : Icons.public_outlined,
      enabled: hasPerm,
      globalFlag: 'enable_edit_quiz',
      isAdmin: isAdmin,
      onTap: onTap,
    );
  }
}

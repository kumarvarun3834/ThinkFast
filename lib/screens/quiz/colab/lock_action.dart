import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class LockAction extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final bool isAdmin;
  final bool hasPerm;
  final VoidCallback onTap;

  const LockAction({
    super.key,
    required this.quizData,
    required this.isAdmin,
    required this.hasPerm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: quizData['isLocked'] == true ? "Unlock Quiz" : "Lock Quiz",
      icon: quizData['isLocked'] == true ? Icons.lock_open_rounded : Icons.lock_person_rounded,
      enabled: hasPerm,
      globalFlag: 'management_features',
      isAdmin: isAdmin,
      onTap: onTap,
    );
  }
}

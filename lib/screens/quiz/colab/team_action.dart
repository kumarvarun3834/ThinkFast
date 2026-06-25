import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class TeamAction extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final bool isAdmin;
  final bool hasPerm;

  const TeamAction({
    super.key,
    required this.quizData,
    required this.isAdmin,
    required this.hasPerm,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: "Collaborators",
      icon: Icons.people_outline,
      enabled: hasPerm,
      globalFlag: 'management_features',
      isAdmin: isAdmin,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          "/Manage Collaborators",
          arguments: quizData['id'],
        );
      },
    );
  }
}

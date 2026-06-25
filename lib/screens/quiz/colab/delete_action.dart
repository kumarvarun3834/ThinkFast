import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class DeleteAction extends StatelessWidget {
  final bool isAdmin;
  final bool hasPerm;
  final VoidCallback onTap;

  const DeleteAction({
    super.key,
    required this.isAdmin,
    required this.hasPerm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: "Delete Quiz",
      icon: Icons.delete_outline,
      enabled: hasPerm,
      globalFlag: 'enable_delete_quiz',
      isAdmin: isAdmin,
      onTap: onTap,
      isDestructive: true,
    );
  }
}

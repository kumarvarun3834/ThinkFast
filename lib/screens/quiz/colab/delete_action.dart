import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class DeleteAction extends StatelessWidget {
  final bool isAdmin;
  final bool hasPerm;
  final VoidCallback onTap;
  final bool isDeleted;

  const DeleteAction({
    super.key,
    required this.isAdmin,
    required this.hasPerm,
    required this.onTap,
    this.isDeleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: isDeleted ? "Recover Quiz" : "Delete Quiz",
      icon: isDeleted ? Icons.restore_from_trash : Icons.delete_outline,
      enabled: hasPerm,
      globalFlag: 'enable_delete_quiz',
      isAdmin: isAdmin,
      onTap: onTap,
      isDestructive: !isDeleted,
    );
  }
}

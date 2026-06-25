import 'package:flutter/material.dart';
import 'manage_action_tile.dart';

class UpdateAction extends StatelessWidget {
  final bool isAdmin;
  final bool hasPerm;
  final VoidCallback onTap;

  const UpdateAction({
    super.key,
    required this.isAdmin,
    required this.hasPerm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ManageActionTile(
      text: "Update Quiz",
      icon: Icons.edit_outlined,
      enabled: hasPerm,
      globalFlag: 'enable_edit_quiz',
      isAdmin: isAdmin,
      onTap: onTap,
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'visibility_action.dart';
import 'lock_action.dart';
import 'responses_action.dart';
import 'team_action.dart';
import 'update_action.dart';
import 'delete_action.dart';
import 'manage_action_tile.dart';

class ManagementBottomSheet extends StatelessWidget {
  final Map<String, dynamic> quizData;
  final bool isAdmin;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const ManagementBottomSheet({
    super.key,
    required this.quizData,
    required this.isAdmin,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOwner =
        FirebaseAuth.instance.currentUser != null &&
        quizData['creatorId'] == FirebaseAuth.instance.currentUser!.uid;
    final String quizId = quizData['id'];

    bool hasPerm(String perm, {bool isContentRestricted = false}) {
      // Rule: Admins cannot see/edit internal quiz data for quizzes they don't explicitly manage.
      if (isAdmin && isContentRestricted) {
        // Only allow if they are owner or have explicit management record or have privacy bypass
        if (isOwner) return true;
        final explicitPerms = global.managedQuizzes[quizId];
        if (explicitPerms?[perm] == true) return true;

        // Optional Bypass: Platform admins can see/edit if they have the specific permission
        return global.adminPermissions.contains('bypass_quiz_privacy');
      }

      if (isAdmin || isOwner) return true;
      final perms = global.managedQuizzes[quizId];
      return perms?[perm] == true;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: global.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "MANAGE QUIZ",
            style: GoogleFonts.poppins(
              color: global.primaryAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VisibilityAction(
                    quizData: quizData,
                    isAdmin: isAdmin,
                    hasPerm: hasPerm('can_publish'),
                    onTap: onToggleVisibility,
                  ),
                  LockAction(
                    quizData: quizData,
                    isAdmin: isAdmin,
                    hasPerm: hasPerm('can_lock_quiz') || hasPerm('can_update'),
                    onTap: onToggleLock,
                  ),
                  ResponsesAction(
                    quizData: quizData,
                    isAdmin: isAdmin,
                    hasPerm: hasPerm('can_view_results'),
                  ),
                  TeamAction(
                    quizData: quizData,
                    isAdmin: isAdmin,
                    hasPerm: hasPerm('can_manage_collaborators'),
                  ),
                  ManageActionTile(
                    icon: Icons.leaderboard_rounded,
                    text: "Manage Leaderboards",
                    enabled: hasPerm('canModerate'),
                    isAdmin: isAdmin,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/Manage Leaderboards', arguments: quizId);
                    },
                  ),
                  if (!(quizData['isPersonal'] == true) || isAdmin) ...[
                    UpdateAction(
                      isAdmin: isAdmin,
                      hasPerm: hasPerm('can_update', isContentRestricted: true),
                      onTap: onUpdate,
                    ),
                    DeleteAction(
                      isAdmin: isAdmin,
                      hasPerm: hasPerm('can_delete'),
                      onTap: onDelete,
                      isDeleted: quizData['isDeleted'] == true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

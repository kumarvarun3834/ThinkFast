import 'package:flutter/material.dart';
import 'package:thinkfast/utils/global.dart' as global;

class CollaboratorTile extends StatelessWidget {
  final Map<String, dynamic> collaborator;
  final bool canManageThisTeam;
  final String? currentUserId;
  final Function(String, String) onRemove;
  final bool isAdmin;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const CollaboratorTile({
    super.key,
    required this.collaborator,
    required this.canManageThisTeam,
    required this.currentUserId,
    required this.onRemove,
    required this.isAdmin,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = collaborator['userName'] ?? "Unknown User";
    final String? photoUrl = collaborator['userPhoto'];
    final String uid = collaborator['userId'];
    final Map<String, dynamic> perms = collaborator['permissions'] as Map<String, dynamic>? ?? {};

    // Check Global Feature Flag
    final bool managementEnabled = global.featureFlags?['management_features'] ?? true;
    final bool effectiveManageEnabled = canManageThisTeam && (isAdmin || managementEnabled);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? global.primaryAccent.withOpacity(0.1) : global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? global.primaryAccent : global.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: global.bgColor,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, color: global.primaryAccent) : null,
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: global.primaryAccent, size: 14),
                    ),
                  ),
              ],
            ),
            title: Text(
              name,
              style: const TextStyle(color: global.valueColor, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(uid, style: const TextStyle(color: global.labelColor, fontSize: 10)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: perms.entries
                      .where((e) => e.value == true)
                      .map((e) => _buildPermissionBadge(e.key))
                      .toList(),
                ),
              ],
            ),
            trailing: isSelectionMode || uid == currentUserId
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: effectiveManageEnabled ? global.errorColor : global.labelColor.withOpacity(0.3),
                    ),
                    onPressed: () {
                      if (effectiveManageEnabled) {
                        onRemove(uid, name);
                      } else {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Access Denied: Caller does not have permission to perform this action."),
                            backgroundColor: global.errorColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(String key) {
    final display = key.replaceAll('can_', '').replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: global.primaryAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: global.primaryAccent.withOpacity(0.3)),
      ),
      child: Text(
        display,
        style: const TextStyle(color: global.primaryAccent, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}

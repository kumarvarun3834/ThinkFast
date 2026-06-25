import 'package:flutter/material.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ManageActionTile extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String? globalFlag;
  final bool isDestructive;
  final bool isAdmin;

  const ManageActionTile({
    super.key,
    required this.text,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.globalFlag,
    this.isDestructive = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Check Global Feature Flag
    bool isFlagEnabled = true;
    if (globalFlag != null && !isAdmin) {
      isFlagEnabled = global.featureFlags?[globalFlag] ?? true;
    }

    // 2. Hide if flag is completely off and user is not admin
    if (!isFlagEnabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        onTap: enabled
            ? onTap
            : () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Access Denied: Caller does not have permission to perform this action."),
                    backgroundColor: global.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
        leading: Icon(
          icon,
          color: enabled
              ? (isDestructive ? global.errorColor : global.primaryAccent)
              : global.labelColor.withOpacity(0.4),
        ),
        title: Text(
          text,
          style: TextStyle(
            color: enabled
                ? (isDestructive ? global.errorColor : global.valueColor)
                : global.valueColor.withOpacity(0.4),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: !enabled
            ? Icon(Icons.lock, size: 16, color: global.labelColor.withOpacity(0.4))
            : Icon(Icons.chevron_right, size: 16, color: global.labelColor.withOpacity(0.6)),
      ),
    );
  }
}

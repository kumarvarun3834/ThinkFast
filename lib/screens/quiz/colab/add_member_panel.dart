import 'package:flutter/material.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AddMemberPanel extends StatefulWidget {
  final String quizId;
  final bool isAdmin;
  final String? currentUserId;

  const AddMemberPanel({
    super.key,
    required this.quizId,
    required this.isAdmin,
    this.currentUserId,
  });

  @override
  State<AddMemberPanel> createState() => _AddMemberPanelState();
}

class _AddMemberPanelState extends State<AddMemberPanel> {
  final TextEditingController _userIdController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  bool _isProcessing = false;

  final Map<String, bool> _permissions = {
    'can_update': true,
    'can_delete': false,
    'can_publish': false,
    'can_view_results': true,
    'can_view_answer_key': false,
    'can_view_analytics': false,
    'can_export_data': false,
    'can_moderate': false,
    'can_manage_collaborators': false,
    'can_ban_users': false,
    'can_lock_quiz': false,
  };

  void _addCollaborators() async {
    final String input = _userIdController.text.trim();
    if (input.isEmpty) return;

    final List<String> targetIds = input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (targetIds.isEmpty) return;

    final String? currentUserId = widget.currentUserId;
    if (currentUserId == null) return;

    setState(() => _isProcessing = true);
    int successCount = 0;
    List<String> failedIds = [];

    try {
      for (String targetId in targetIds) {
        try {
          await _db.grantManagementAccess(
            quizId: widget.quizId,
            userId: targetId,
            permissions: Map.from(_permissions),
            addedBy: currentUserId,
          );
          successCount++;
        } catch (e) {
          failedIds.add(targetId);
        }
      }

      _userIdController.clear();
      if (mounted) {
        if (failedIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$successCount collaborator(s) added successfully")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Added $successCount. Failed for: ${failedIds.join(', ')}"),
              backgroundColor: global.warningColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool managementEnabled = global.featureFlags?['management_features'] ?? true;
    final bool effectiveEnabled = (widget.isAdmin || managementEnabled) && !_isProcessing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: effectiveEnabled ? global.borderColor : global.borderColor.withOpacity(0.3),
        ),
      ),
      child: Opacity(
        opacity: effectiveEnabled ? 1.0 : 0.6,
        child: AbsorbPointer(
          absorbing: !effectiveEnabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _userIdController,
                style: const TextStyle(color: global.valueColor),
                decoration: InputDecoration(
                  hintText: "Enter User ID(s), comma separated",
                  hintStyle: const TextStyle(color: global.labelColor),
                  filled: true,
                  fillColor: global.bgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: global.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPermissionGroup("Content Management", [
                _buildPermissionSwitch("Edit Questions", 'can_update'),
                _buildPermissionSwitch("Delete Quiz", 'can_delete'),
                _buildPermissionSwitch("Publish/Visibility", 'can_publish'),
                _buildPermissionSwitch("Lock/Unlock Session", 'can_lock_quiz'),
              ]),
              const SizedBox(height: 12),
              _buildPermissionGroup("Data & Analytics", [
                _buildPermissionSwitch("View Responses", 'can_view_results'),
                _buildPermissionSwitch("View Answer Key", 'can_view_answer_key'),
                _buildPermissionSwitch("Advanced Analytics", 'can_view_analytics'),
                _buildPermissionSwitch("Export Data", 'can_export_data'),
              ]),
              const SizedBox(height: 12),
              _buildPermissionGroup("Moderation & Team", [
                _buildPermissionSwitch("Moderate Responses", 'can_moderate'),
                _buildPermissionSwitch("Ban Users", 'can_ban_users'),
                _buildPermissionSwitch("Manage Team", 'can_manage_collaborators'),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: effectiveEnabled
                      ? _addCollaborators
                      : () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Access Denied: Caller does not have permission to perform this action."),
                              backgroundColor: global.errorColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveEnabled ? global.primaryAccent : global.hintColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "GRANT ACCESS",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: global.labelColor, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  Widget _buildPermissionSwitch(String title, String key) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: global.valueColor, fontSize: 14)),
      value: _permissions[key] ?? false,
      activeColor: global.primaryAccent,
      onChanged: (v) => setState(() => _permissions[key] = v),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

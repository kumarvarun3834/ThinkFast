import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AddCollaboratorScreen extends StatefulWidget {
  final String quizId;
  final bool isAdmin;
  final String? currentUserId;

  const AddCollaboratorScreen({
    super.key,
    required this.quizId,
    required this.isAdmin,
    this.currentUserId,
  });

  @override
  State<AddCollaboratorScreen> createState() => _AddCollaboratorScreenState();
}

class _AddCollaboratorScreenState extends State<AddCollaboratorScreen> {
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

    final List<String> targetIds = input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
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

      if (mounted) {
        if (failedIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("$successCount collaborator(s) added successfully")),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Added $successCount. Failed for: ${failedIds.join(', ')}"),
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
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Add Collaborators",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        iconTheme: const IconThemeData(color: global.valueColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User IDs",
              style: GoogleFonts.poppins(
                color: global.primaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userIdController,
              style: const TextStyle(color: global.valueColor),
              decoration: InputDecoration(
                hintText: "Enter User ID(s), comma separated",
                hintStyle: const TextStyle(color: global.labelColor),
                filled: true,
                fillColor: global.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: global.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: global.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: global.primaryAccent),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Permissions"),
            const SizedBox(height: 16),
            _buildPermissionGroup("Content Management", [
              _buildPermissionSwitch("Edit Questions", 'can_update'),
              _buildPermissionSwitch("Delete Quiz", 'can_delete'),
              _buildPermissionSwitch("Publish/Visibility", 'can_publish'),
              _buildPermissionSwitch("Lock/Unlock Session", 'can_lock_quiz'),
            ]),
            const SizedBox(height: 24),
            _buildPermissionGroup("Data & Analytics", [
              _buildPermissionSwitch("View Responses", 'can_view_results'),
              _buildPermissionSwitch("View Answer Key", 'can_view_answer_key'),
              _buildPermissionSwitch("Advanced Analytics", 'can_view_analytics'),
              _buildPermissionSwitch("Export Data", 'can_export_data'),
            ]),
            const SizedBox(height: 24),
            _buildPermissionGroup("Moderation & Team", [
              _buildPermissionSwitch("Moderate Responses", 'can_moderate'),
              _buildPermissionSwitch("Ban Users", 'can_ban_users'),
              _buildPermissionSwitch("Manage Team", 'can_manage_collaborators'),
            ]),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _addCollaborators,
                style: ElevatedButton.styleFrom(
                  backgroundColor: global.primaryAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Text(
                        "GRANT ACCESS",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1.1),
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildPermissionGroup(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: global.valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPermissionSwitch(String title, String key) {
    return SwitchListTile(
      title: Text(title,
          style: const TextStyle(color: global.labelColor, fontSize: 13)),
      value: _permissions[key] ?? false,
      activeColor: global.primaryAccent,
      onChanged: (v) => setState(() => _permissions[key] = v),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

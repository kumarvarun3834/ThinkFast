import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class QuizCollaboratorsScreen extends StatefulWidget {
  final String quizId;

  const QuizCollaboratorsScreen({super.key, required this.quizId});

  @override
  State<QuizCollaboratorsScreen> createState() =>
      _QuizCollaboratorsScreenState();
}

class _QuizCollaboratorsScreenState extends State<QuizCollaboratorsScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Permissions for the new manager
  bool _canUpdate = true;
  bool _canDelete = false;
  bool _canPublish = false;
  bool _canViewResults = true;
  bool _canViewAnswerKey = false;
  bool _canViewAnalytics = false;
  bool _canExportData = false;
  bool _canModerate = false;
  bool _canManageCollaborators = false;
  bool _canBanUsers = false;

  final Color _bgColor = const Color(0xFF0F172A);
  final Color _cardColor = const Color(0xFF1E293B);
  final Color _primaryAccent = const Color(0xFF3B82F6);
  final Color _valueColor = const Color(0xFFE2E8F0);
  final Color _labelColor = const Color(0xFF94A3B8);
  final Color _borderColor = const Color(0xFF334155);

  void _addCollaborator() async {
    final String targetId = _userIdController.text.trim();
    if (targetId.isEmpty || _currentUserId == null) return;

    try {
      await _db.grantManagementAccess(
        quizId: widget.quizId,
        userId: targetId,
        permissions: {
          'can_update': _canUpdate,
          'can_delete': _canDelete,
          'can_publish': _canPublish,
          'can_view_results': _canViewResults,
          'can_view_answer_key': _canViewAnswerKey,
          'can_view_analytics': _canViewAnalytics,
          'can_export_data': _canExportData,
          'canModerate': _canModerate, // Maintain camelCase for existing Dart logic
          'can_manage_collaborators': _canManageCollaborators,
          'can_ban_users': _canBanUsers,
        },
        addedBy: _currentUserId,
      );
      _userIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Collaborator added successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Collaborators",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ADD NEW COLLABORATOR",
                    style: GoogleFonts.poppins(
                      color: _primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userIdController,
                    style: TextStyle(color: _valueColor),
                    decoration: InputDecoration(
                      hintText: "Enter User ID",
                      hintStyle: TextStyle(color: _labelColor),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "CONTENT MANAGEMENT",
                    style: TextStyle(color: _labelColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  _buildPermissionSwitch(
                    "Edit Questions & Scheme",
                    _canUpdate,
                    (v) => setState(() => _canUpdate = v),
                  ),
                  _buildPermissionSwitch(
                    "Delete Quiz",
                    _canDelete,
                    (v) => setState(() => _canDelete = v),
                  ),
                  _buildPermissionSwitch(
                    "Change Visibility (Publish)",
                    _canPublish,
                    (v) => setState(() => _canPublish = v),
                  ),
                  const Divider(color: Color(0xFF334155), height: 24),
                  Text(
                    "DATA & ANALYTICS",
                    style: TextStyle(color: _labelColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  _buildPermissionSwitch(
                    "View Participant Responses",
                    _canViewResults,
                    (v) => setState(() => _canViewResults = v),
                  ),
                  _buildPermissionSwitch(
                    "View Answer Key & Solutions",
                    _canViewAnswerKey,
                    (v) => setState(() => _canViewAnswerKey = v),
                  ),
                  _buildPermissionSwitch(
                    "Access Advanced Analytics",
                    _canViewAnalytics,
                    (v) => setState(() => _canViewAnalytics = v),
                  ),
                  _buildPermissionSwitch(
                    "Export Data (CSV/JSON)",
                    _canExportData,
                    (v) => setState(() => _canExportData = v),
                  ),
                  const Divider(color: Color(0xFF334155), height: 24),
                  Text(
                    "MODERATION & TEAM",
                    style: TextStyle(color: _labelColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  _buildPermissionSwitch(
                    "Moderate Responses (Soft-Delete)",
                    _canModerate,
                    (v) => setState(() => _canModerate = v),
                  ),
                  _buildPermissionSwitch(
                    "Ban/Unban Users",
                    _canBanUsers,
                    (v) => setState(() => _canBanUsers = v),
                  ),
                  _buildPermissionSwitch(
                    "Manage Other Collaborators",
                    _canManageCollaborators,
                    (v) => setState(() => _canManageCollaborators = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _addCollaborator,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "GRANT ACCESS",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // I'll need to expose a stream for managers in DatabaseService
              stream: _db.getQuizManagers(widget.quizId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final managers = snapshot.data ?? [];
                if (managers.isEmpty) {
                  return Center(
                    child: Text(
                      "No collaborators yet",
                      style: TextStyle(color: _labelColor),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    MediaQuery.of(context).padding.bottom + 40,
                  ),
                  itemCount: managers.length,
                  itemBuilder: (context, index) {
                    final m = managers[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          title: Text(
                            m['userId'],
                            style: TextStyle(
                              color: _valueColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: (m['permissions'] as Map<String, dynamic>)
                                .entries
                                .where((e) => e.value == true)
                                .map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _primaryAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: _primaryAccent.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        e.key.replaceAll('can_', '').replaceAll('can', '').toUpperCase(),
                                        style: TextStyle(color: _primaryAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ))
                                .toList(),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: _cardColor,
                                  title: const Text(
                                    "Remove Collaborator?",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    "Are you sure you want to remove access for ${m['userId']}?",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Remove"),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && _currentUserId != null) {
                                try {
                                  await _db.removeManagementAccess(
                                    quizId: widget.quizId,
                                    userId: m['userId'],
                                    removedBy: _currentUserId,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Collaborator removed"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSwitch(
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: _valueColor, fontSize: 14)),
      value: value,
      activeColor: _primaryAccent,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

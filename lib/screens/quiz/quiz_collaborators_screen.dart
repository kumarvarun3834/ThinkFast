import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

import '../../utils/global.dart' as global;

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

  bool _isAdmin = false;
  bool _isOwner = false;
  bool _canManageThisTeam = false;
  bool _canLockUnlock = false;

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
  bool _canLockQuiz = false;

  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (_currentUserId == null) return;
    try {
      final isAdmin = await _db.isAdmin(_currentUserId!);
      final metadata = await _db.readDatabase(
        widget.quizId,
        userId: _currentUserId,
      );
      final isOwner = metadata['creatorId'] == _currentUserId;

      // Check for specific 'can_manage_collaborators' permission
      final perms = global.managedQuizzes[widget.quizId];
      final bool hasManagerPerm = perms?['can_manage_collaborators'] == true;
      final bool hasLockPerm =
          perms?['can_lock_quiz'] == true || perms?['can_update'] == true;

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isOwner = isOwner;
          _canManageThisTeam = isAdmin || isOwner || hasManagerPerm;
          _canLockUnlock = isAdmin || isOwner || hasLockPerm;
        });
      }
    } catch (e) {
      debugPrint("Error loading collaborator screen permissions: $e");
    }
  }

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
          'can_moderate': _canModerate, // Unified to snake_case
          'can_manage_collaborators': _canManageCollaborators,
          'can_ban_users': _canBanUsers,
          'can_lock_quiz': _canLockQuiz,
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

  Future<void> _toggleLock(bool isLocked) async {
    if (_currentUserId == null) return;
    try {
      await _db.toggleQuizLock(
        docId: widget.quizId,
        currentUserId: _currentUserId!,
        isLocked: isLocked,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isLocked ? "Quiz Locked" : "Quiz Unlocked")),
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
          "Manage Quiz",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.quizId)
            .snapshots(),
        builder: (context, quizSnapshot) {
          final quizData = quizSnapshot.data?.data() as Map<String, dynamic>?;
          final bool isLocked = quizData?['isLocked'] ?? false;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.getQuizManagers(widget.quizId),
            builder: (context, managersSnapshot) {
              if (managersSnapshot.hasError) {
                return Center(
                  child: Text(
                    "Error loading team: ${managersSnapshot.error}",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              final managers = managersSnapshot.data ?? [];
              final bool isLoadingManagers =
                  managersSnapshot.connectionState == ConnectionState.waiting;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // --- QUIZ STATUS SECTION ---
                  _buildSectionHeader("Quiz Status"),
                  const SizedBox(height: 12),
                  _buildStatusTile(isLocked),
                  const SizedBox(height: 32),

                  // --- ADD COLLABORATOR SECTION ---
                  if (_canManageThisTeam) ...[
                    _buildSectionHeader("Add New Collaborator"),
                    const SizedBox(height: 12),
                    _buildAddCollaboratorForm(),
                    const SizedBox(height: 32),
                  ],

                  // --- CURRENT TEAM SECTION ---
                  _buildSectionHeader("Current Team"),
                  const SizedBox(height: 12),
                  if (isLoadingManagers)
                    const Center(child: CircularProgressIndicator())
                  else if (managers.isEmpty)
                    _buildEmptyState("No collaborators yet")
                  else
                    ...managers.map((m) => _buildCollaboratorTile(m)).toList(),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: _primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStatusTile(bool isLocked) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canLockUnlock ? _borderColor : _borderColor.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            isLocked ? "Quiz is LOCKED" : "Quiz is UNLOCKED",
            style: TextStyle(
              color: _canLockUnlock
                  ? _valueColor
                  : _valueColor.withOpacity(0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            isLocked
                ? "New attempts are blocked"
                : "Users can start new attempts",
            style: TextStyle(
              color: _canLockUnlock
                  ? _labelColor
                  : _labelColor.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          secondary: Icon(
            isLocked ? Icons.lock_person : Icons.lock_open_rounded,
            color: isLocked ? Colors.redAccent : Colors.greenAccent,
          ),
          value: isLocked,
          activeTrackColor: Colors.redAccent.withOpacity(0.5),
          activeThumbColor: Colors.redAccent,
          onChanged: _canLockUnlock ? (v) => _toggleLock(v) : null,
        ),
      ),
    );
  }

  Widget _buildAddCollaboratorForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _userIdController,
            style: TextStyle(color: _valueColor),
            decoration: InputDecoration(
              hintText: "Enter User ID",
              hintStyle: TextStyle(color: _labelColor),
              filled: true,
              fillColor: _bgColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPermissionGroup("Content Management", [
            _buildPermissionSwitch(
              "Edit Questions",
              _canUpdate,
              (v) => setState(() => _canUpdate = v),
            ),
            _buildPermissionSwitch(
              "Delete Quiz",
              _canDelete,
              (v) => setState(() => _canDelete = v),
            ),
            _buildPermissionSwitch(
              "Publish/Visibility",
              _canPublish,
              (v) => setState(() => _canPublish = v),
            ),
            _buildPermissionSwitch(
              "Lock/Unlock Session",
              _canLockQuiz,
              (v) => setState(() => _canLockQuiz = v),
            ),
          ]),
          const SizedBox(height: 12),
          _buildPermissionGroup("Data & Analytics", [
            _buildPermissionSwitch(
              "View Responses",
              _canViewResults,
              (v) => setState(() => _canViewResults = v),
            ),
            _buildPermissionSwitch(
              "View Answer Key",
              _canViewAnswerKey,
              (v) => setState(() => _canViewAnswerKey = v),
            ),
            _buildPermissionSwitch(
              "Advanced Analytics",
              _canViewAnalytics,
              (v) => setState(() => _canViewAnalytics = v),
            ),
            _buildPermissionSwitch(
              "Export Data",
              _canExportData,
              (v) => setState(() => _canExportData = v),
            ),
          ]),
          const SizedBox(height: 12),
          _buildPermissionGroup("Moderation & Team", [
            _buildPermissionSwitch(
              "Moderate Responses",
              _canModerate,
              (v) => setState(() => _canModerate = v),
            ),
            _buildPermissionSwitch(
              "Ban Users",
              _canBanUsers,
              (v) => setState(() => _canBanUsers = v),
            ),
            _buildPermissionSwitch(
              "Manage Team",
              _canManageCollaborators,
              (v) => setState(() => _canManageCollaborators = v),
            ),
          ]),
          const SizedBox(height: 24),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: _labelColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
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

  Widget _buildCollaboratorTile(Map<String, dynamic> m) {
    final String name = m['userName'] ?? "Unknown User";
    final String? photoUrl = m['userPhoto'];
    final String uid = m['userId'];
    final Map<String, dynamic> perms =
        m['permissions'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _bgColor,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? const Icon(Icons.person, color: global.primaryAccent)
              : null,
        ),
        title: Text(
          name,
          style: TextStyle(color: _valueColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uid, style: TextStyle(color: _labelColor, fontSize: 10)),
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
        trailing: _canManageThisTeam && uid != _currentUserId
            ? IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: global.errorColor,
                ),
                onPressed: () => _confirmRemove(uid, name),
              )
            : null,
      ),
    );
  }

  Widget _buildPermissionBadge(String key) {
    final display = key
        .replaceAll('can_', '')
        .replaceAll('_', ' ')
        .toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _primaryAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _primaryAccent.withOpacity(0.3)),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: _primaryAccent,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(message, style: TextStyle(color: _labelColor)),
      ),
    );
  }

  void _confirmRemove(String uid, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          "Remove Collaborator?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to revoke access for $name?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("REMOVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && _currentUserId != null) {
      try {
        await _db.removeManagementAccess(
          quizId: widget.quizId,
          userId: uid,
          removedBy: _currentUserId!,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Collaborator removed")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/global.dart' as global;

class QuizBannedUsersScreen extends StatefulWidget {
  final String quizId;

  const QuizBannedUsersScreen({super.key, required this.quizId});

  @override
  State<QuizBannedUsersScreen> createState() => _QuizBannedUsersScreenState();
}

class _QuizBannedUsersScreenState extends State<QuizBannedUsersScreen> {
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;
  bool _isAdmin = false;
  bool _isOwner = false;
  Map<String, dynamic>? _quizMetadata;

  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  late Stream<List<Map<String, dynamic>>> _bannedUsersStream;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _bannedUsersStream = global.qDb.getQuizBannedUsers(widget.quizId);
  }

  Future<void> _loadPermissions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final metadata = await global.db.readDatabase(widget.quizId, userId: uid);
      final isAdmin = await global.db.isAdmin(uid);

      if (mounted) {
        setState(() {
          _quizMetadata = metadata;
          _isAdmin = isAdmin;
          _isOwner = metadata['creatorId'] == uid;
        });
      }
    } catch (e) {
      debugPrint("Error loading ban management permissions: $e");
    }
  }

  bool _hasPerm(String perm) {
    if (_isAdmin || _isOwner) return true;
    final perms = global.managedQuizzes[widget.quizId];
    if (perms == null) return false;

    if (perm == 'canModerate' || perm == 'can_moderate')
      return perms['canModerate'] == true || perms['can_moderate'] == true;
    if (perm == 'can_update' || perm == 'canUpdateData')
      return perms['can_update'] == true || perms['canUpdateData'] == true;
    return perms[perm] == true;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedUserIds.contains(id)) {
        _selectedUserIds.remove(id);
        if (_selectedUserIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedUserIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleBulkUnban() async {
    if (_selectedUserIds.isEmpty) return;

    if (!(_isAdmin || (global.featureFlags?['management_features'] ?? true))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Denied: Moderation features are disabled."),
          backgroundColor: global.errorColor,
        ),
      );
      return;
    }

    if (!_hasPerm('can_ban_users') && !_hasPerm('canModerate')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Access Denied: Caller does not have permission to perform this action.",
          ),
          backgroundColor: global.errorColor,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          "Unblock Selected Users?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "These users will be allowed to take the quiz again.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.primaryAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("UNBLOCK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final adminId = FirebaseAuth.instance.currentUser!.uid;

      try {
        for (String id in _selectedUserIds) {
          final userId = id.split('_').last;
          await global.qDb.unbanUser(
            userId: userId,
            quizId: widget.quizId,
            adminId: adminId,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${_selectedUserIds.length} users unblocked"),
            ),
          );
          setState(() {
            _selectedUserIds.clear();
            _isSelectionMode = false;
          });
        }
      } catch (e) {
        if (mounted)
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
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedUserIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedUserIds.length} Selected",
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                "Blocked Users",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _valueColor,
                ),
              ),
        iconTheme: IconThemeData(color: _valueColor),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(
                    Icons.person_add_rounded,
                    color: global.successColor,
                  ),
                  onPressed: _handleBulkUnban,
                ),
              ]
            : [],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bannedUsersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded, size: 64, color: _borderColor),
                  const SizedBox(height: 16),
                  Text(
                    "No blocked users found",
                    style: GoogleFonts.poppins(color: _labelColor),
                  ),
                ],
              ),
            );

          final bannedUsers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bannedUsers.length,
            itemBuilder: (context, index) {
              final user = bannedUsers[index];
              final String id = user['id'];
              final bool isSelected = _selectedUserIds.contains(id);
              final bool hasPerm =
                  _hasPerm('can_ban_users') || _hasPerm('canModerate');
              final bool flagEnabled =
                  _isAdmin ||
                  (global.featureFlags?['management_features'] ?? true);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryAccent.withOpacity(0.15)
                      : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primaryAccent : _borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onLongPress: () => _toggleSelection(id),
                    onTap: _isSelectionMode ? () => _toggleSelection(id) : null,
                    leading: CircleAvatar(
                      backgroundColor: _borderColor,
                      backgroundImage: user['userPhoto'] != null
                          ? NetworkImage(user['userPhoto'])
                          : null,
                      child: user['userPhoto'] == null
                          ? Icon(Icons.person, color: _labelColor)
                          : null,
                    ),
                    title: Text(
                      user['userName'] ?? "Unknown User",
                      style: GoogleFonts.poppins(
                        color: _valueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user['userEmail'] != null)
                          Text(
                            user['userEmail'],
                            style: GoogleFonts.poppins(
                              color: _labelColor,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          "Reason: ${user['reason'] ?? 'No reason provided'}",
                          style: GoogleFonts.poppins(
                            color: global.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: _isSelectionMode
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.person_add_rounded,
                              color: hasPerm && flagEnabled
                                  ? global.successColor
                                  : global.labelColor.withOpacity(0.3),
                            ),
                            onPressed: () {
                              if (!flagEnabled) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Access Denied: Moderation features are disabled.",
                                    ),
                                    backgroundColor: global.errorColor,
                                  ),
                                );
                                return;
                              }
                              if (hasPerm)
                                _confirmUnban(user);
                              else
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Access Denied: Caller does not have permission to perform this action.",
                                    ),
                                    backgroundColor: global.errorColor,
                                  ),
                                );
                            },
                            tooltip: "Unblock User",
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmUnban(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "Unblock ${user['userName'] ?? 'User'}?",
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This user will be able to take the quiz again.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.successColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              try {
                await global.qDb.unbanUser(
                  userId: user['userId'],
                  quizId: widget.quizId,
                  adminId: FirebaseAuth.instance.currentUser!.uid,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User unblocked successfully")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Unblock"),
          ),
        ],
      ),
    );
  }
}

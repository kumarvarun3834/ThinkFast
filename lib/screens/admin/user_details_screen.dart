import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

import '../../widgets/quiz_widgets.dart';
import '../quiz/result_screen.dart';
import 'admin_permissions_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;

  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late final String? _adminId = FirebaseAuth.instance.currentUser?.uid;
  bool _isBanned = false;
  bool _isAppAdmin = false;
  List<String> _adminPermissions = [];
  int _adminLevel = 1;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final banned = await global.db.isUserBanned(widget.userId);
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(widget.userId).get();
    
    if (mounted) {
      setState(() {
        _isBanned = banned;
        _isAppAdmin = adminDoc.exists;
        if (adminDoc.exists) {
          final data = adminDoc.data()!;
          _adminPermissions = List<String>.from(data['permissions'] ?? []);
          _adminLevel = data['level'] ?? 1;
        }
      });
    }
  }

  void _handleDelete() async {
    if (_adminId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text(
          "Delete User Account?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will permanently remove the user's Firestore data and admin status. "
          "They may still be able to log in to Auth, but will have no profile. "
          "This action is IRREVERSIBLE.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await global.adminDb.deleteUserAccount(
          targetUid: widget.userId,
          adminId: _adminId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("User account deleted")));
          Navigator.pop(context);
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

  void _handleBan() async {
    if (_adminId == null) return;
    if (_isBanned) {
      try {
        await global.adminDb.unbanUser(userId: widget.userId, adminId: _adminId);
        setState(() => _isBanned = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("User unbanned")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    } else {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: global.cardColor,
          title: const Text(
            "Ban User Globally?",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Reason for ban...",
              hintStyle: TextStyle(color: global.labelColor),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: global.warningColor,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("BAN"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await global.adminDb.banUser(
            userId: widget.userId,
            reason: reasonController.text.trim(),
            adminId: _adminId!,
          );
          setState(() => _isBanned = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User banned globally")),
            );
          }
        } catch (e) {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adminId == null)
      return const Scaffold(body: Center(child: Text("Unauthorized")));

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "User Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: global.adminDb.getFullUserProfile(widget.userId, _adminId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null)
            return const Center(
              child: Text(
                "User not found",
                style: TextStyle(color: global.labelColor),
              ),
            );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 24),
              _buildStats(user),
              const SizedBox(height: 24),
              _buildDetailedInfo(user),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 32),
              _buildSectionHeader("USER QUIZZES"),
              const SizedBox(height: 12),
              _buildQuizzesList(),
              const SizedBox(height: 32),
              _buildSectionHeader("USER ATTEMPTS"),
              const SizedBox(height: 12),
              _buildAttemptsList(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailedInfo(Map<String, dynamic> user) {
    final fields = {
      'Grade/Class': user['class'],
      'Study Goal': user['goal'],
      'Learning Style': user['learningStyle'],
      'Interests': (user['interests'] as List?)?.join(', '),
      'Last Active': (user['lastActive'] as Timestamp?)?.toDate().toString(),
    };

    final validFields = fields.entries.where((e) => e.value != null).toList();
    if (validFields.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: validFields
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      "${e.key}: ",
                      style: const TextStyle(
                        color: global.labelColor,
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value!,
                        style: const TextStyle(
                          color: global.valueColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: global.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: global.bgColor,
            backgroundImage: user['photoUrl'] != null
                ? NetworkImage(user['photoUrl'])
                : null,
            child: user['photoUrl'] == null
                ? const Icon(Icons.person, size: 40, color: global.labelColor)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? "Anonymous",
                  style: const TextStyle(
                    color: global.valueColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['email'] ?? "No Email",
                  style: const TextStyle(
                    color: global.labelColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isBanned
                            ? global.errorColor.withValues(alpha: 0.1)
                            : global.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isBanned ? "BANNED" : "ACTIVE",
                        style: TextStyle(
                          color: _isBanned
                              ? global.errorColor
                              : global.successColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isAppAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                        color: global.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                        child: Text(
                          _adminLevel == 0 ? "SUPER ADMIN" : "APP ADMIN",
                          style: const TextStyle(
                            color: global.primaryAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> user) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard("Quizzes", user['quizCount']?.toString() ?? "0"),
            const SizedBox(width: 12),
            _buildStatCard(
              "Active Attempts",
              user['attemptCount']?.toString() ?? "0",
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              "Deleted Attempts",
              user['deletedAttemptCount']?.toString() ?? "0",
              color: global.errorColor,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              "Total Sessions",
              ((user['attemptCount'] ?? 0) + (user['deletedAttemptCount'] ?? 0))
                  .toString(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: global.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: global.borderColor),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? global.valueColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: global.labelColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool canManageAdmins = global.adminLevel == 0 || global.adminPermissions.contains('manage_admins');

    return Column(
      children: [
        if (canManageAdmins) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminPermissionsScreen(
                      targetUids: [widget.userId],
                      initialPermissions: _isAppAdmin ? _adminPermissions : null,
                      initialIsSuper: _isAppAdmin && _adminLevel == 0,
                    ),
                  ),
                ).then((_) => _fetchStatus());
              },
              icon: Icon(_isAppAdmin ? Icons.security_rounded : Icons.admin_panel_settings_rounded),
              label: Text(_isAppAdmin ? "MANAGE ADMIN PERMISSIONS" : "PROMOTE TO APP ADMIN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: global.primaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleBan,
                icon: Icon(_isBanned ? Icons.gavel : Icons.block),
                label: Text(_isBanned ? "UNBAN USER" : "BAN USER"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBanned
                      ? global.successColor
                      : global.warningColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete_forever),
                label: const Text("DELETE DATA"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: global.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizzesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: global.adminDb.getUserQuizzesMaster(widget.userId, _adminId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final quizzes = snapshot.data ?? [];
        if (quizzes.isEmpty) {
          return const Center(
            child: Text(
              "No quizzes created",
              style: TextStyle(color: global.labelColor),
            ),
          );
        }

        return Column(
          children: quizzes
              .map(
                (q) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: global.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: global.borderColor),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        q['title'] ?? "Untitled",
                        style: const TextStyle(color: global.valueColor),
                      ),
                      subtitle: Text(
                        "${q['visibility'].toUpperCase()} • ${q['isDeleted'] == true ? 'DELETED' : 'LIVE'}",
                        style: TextStyle(
                          color: q['isDeleted'] == true
                              ? global.errorColor
                              : global.labelColor,
                          fontSize: 10,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: global.labelColor,
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          "/Quiz Details",
                          arguments: q['id'],
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAttemptsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: global.adminDb.getUserAttempts(widget.userId, includeDeleted: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final attempts = snapshot.data ?? [];
        if (attempts.isEmpty) {
          return const Center(
            child: Text(
              "No attempts made",
              style: TextStyle(color: global.labelColor),
            ),
          );
        }

        return Column(
          children: attempts
              .map(
                (a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: a['isDeleted'] == true
                        ? global.errorColor.withValues(alpha: 0.05)
                        : global.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: a['isDeleted'] == true
                          ? global.errorColor.withValues(alpha: 0.3)
                          : global.borderColor,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              a['quizTitle'] ?? "Untitled Quiz",
                              style: TextStyle(
                                color: a['isDeleted'] == true
                                    ? global.errorColor.withValues(alpha: 0.8)
                                    : global.valueColor,
                              ),
                            ),
                          ),
                          if (a['isDeleted'] == true)
                            const StatusBadge(
                              text: "DELETED",
                              color: global.errorColor,
                              fontSize: 9,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        "Score: ${a['score']} / ${(a['totalQuestions'] ?? 0) * 4} • ${a['timestamp']?.toDate().toString().split('.')[0]}",
                        style: const TextStyle(
                          color: global.labelColor,
                          fontSize: 10,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: global.labelColor,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultScreen(
                              quizId: a['quizId'],
                              attemptAnswers:
                                  a['answers'] as Map<String, dynamic>,
                              attemptReviewItems:
                                  a['reviewItems'] as List<dynamic>?,
                              attemptQuestionOrder:
                                  a['questionOrder'] as List<dynamic>?,
                              isDeleted: a['isDeleted'] == true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

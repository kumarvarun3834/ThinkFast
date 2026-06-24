import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;

class UserDetailsScreen extends StatefulWidget {
  final String userId;
  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final DatabaseService _db = DatabaseService();
  final String? _adminId = FirebaseAuth.instance.currentUser?.uid;
  bool _isBanned = false;

  @override
  void initState() {
    super.initState();
    _checkBanStatus();
  }

  Future<void> _checkBanStatus() async {
    final banned = await _db.isUserBanned(widget.userId);
    if (mounted) setState(() => _isBanned = banned);
  }

  void _handleDelete() async {
    if (_adminId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Delete User Account?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will permanently remove the user's Firestore data and admin status. "
          "They may still be able to log in to Auth, but will have no profile. "
          "This action is IRREVERSIBLE.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
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
        await _db.deleteUserAccount(targetUid: widget.userId, adminId: _adminId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User account deleted")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _handleBan() async {
    if (_adminId == null) return;
    if (_isBanned) {
      try {
        await _db.unbanUser(userId: widget.userId, adminId: _adminId!);
        setState(() => _isBanned = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User unbanned")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } else {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: global.cardColor,
          title: const Text("Ban User Globally?", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Reason for ban...",
              hintStyle: TextStyle(color: global.labelColor),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: global.warningColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("BAN"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await _db.banUser(
            userId: widget.userId,
            reason: reasonController.text.trim(),
            adminId: _adminId!,
          );
          setState(() => _isBanned = true);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User banned globally")));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adminId == null) return const Scaffold(body: Center(child: Text("Unauthorized")));

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("User Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _db.getFullUserProfile(widget.userId, _adminId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) return const Center(child: Text("User not found", style: TextStyle(color: global.labelColor)));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 24),
              _buildStats(user),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 32),
              Text(
                "USER QUIZZES",
                style: GoogleFonts.poppins(
                  color: global.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuizzesList(),
            ],
          );
        },
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
            backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
            child: user['photoUrl'] == null ? const Icon(Icons.person, size: 40, color: global.labelColor) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? "Anonymous",
                  style: const TextStyle(color: global.valueColor, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  user['email'] ?? "No Email",
                  style: const TextStyle(color: global.labelColor, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isBanned ? global.errorColor.withOpacity(0.1) : global.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _isBanned ? "BANNED" : "ACTIVE",
                    style: TextStyle(
                      color: _isBanned ? global.errorColor : global.successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> user) {
    return Row(
      children: [
        _buildStatCard("Quizzes", user['quizCount']?.toString() ?? "0"),
        const SizedBox(width: 12),
        _buildStatCard("Attempts", user['attemptCount']?.toString() ?? "0"),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
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
            Text(value, style: const TextStyle(color: global.valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: global.labelColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleBan,
            icon: Icon(_isBanned ? Icons.gavel : Icons.block),
            label: Text(_isBanned ? "UNBAN USER" : "BAN USER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isBanned ? global.successColor : global.warningColor,
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
    );
  }

  Widget _buildQuizzesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getUserQuizzesMaster(widget.userId, _adminId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final quizzes = snapshot.data ?? [];
        if (quizzes.isEmpty) {
          return const Center(child: Text("No quizzes created", style: TextStyle(color: global.labelColor)));
        }

        return Column(
          children: quizzes.map((q) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: global.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(q['title'] ?? "Untitled", style: const TextStyle(color: global.valueColor)),
              subtitle: Text(
                "${q['visibility'].toUpperCase()} • ${q['isDeleted'] == true ? 'DELETED' : 'LIVE'}",
                style: TextStyle(
                  color: q['isDeleted'] == true ? global.errorColor : global.labelColor,
                  fontSize: 10,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: global.labelColor),
              onTap: () {
                // Navigate to quiz details if needed
              },
            ),
          )).toList(),
        );
      },
    );
  }
}

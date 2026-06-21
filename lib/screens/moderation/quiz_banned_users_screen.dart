import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
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

  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

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

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text("Unblock Selected Users?", style: TextStyle(color: Colors.white)),
        content: const Text("These users will be allowed to take the quiz again.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.successColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("UNBLOCK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = DatabaseService();
      final adminId = FirebaseAuth.instance.currentUser!.uid;

      try {
        for (String id in _selectedUserIds) {
          final userId = id.split('_').last;
          await db.unbanUser(userId: userId, quizId: widget.quizId, adminId: adminId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${_selectedUserIds.length} users unblocked")),
          );
          setState(() {
            _selectedUserIds.clear();
            _isSelectionMode = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
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
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() {
              _isSelectionMode = false;
              _selectedUserIds.clear();
            }))
          : null,
        title: _isSelectionMode
          ? Text("${_selectedUserIds.length} Selected", style: const TextStyle(color: Colors.white))
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
                icon: const Icon(Icons.person_add_rounded, color: global.successColor),
                onPressed: _handleBulkUnban,
              ),
            ]
          : [],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().getQuizBannedUsers(widget.quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
          }

          final bannedUsers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bannedUsers.length,
            itemBuilder: (context, index) {
              final user = bannedUsers[index];
              final String id = user['id'];
              final bool isSelected = _selectedUserIds.contains(id);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryAccent.withOpacity(0.15) : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? _primaryAccent : _borderColor, width: isSelected ? 2 : 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onLongPress: () => _toggleSelection(id),
                    onTap: _isSelectionMode ? () => _toggleSelection(id) : null,
                    leading: CircleAvatar(
                      backgroundColor: _borderColor,
                      backgroundImage: user['userPhoto'] != null ? NetworkImage(user['userPhoto']) : null,
                      child: user['userPhoto'] == null ? Icon(Icons.person, color: _labelColor) : null,
                    ),
                    title: Row(
                      children: [
                        if (_isSelectionMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                                        color: isSelected ? _primaryAccent : _labelColor, size: 20),
                          ),
                        Text(
                          user['userName'] ?? "Unknown User",
                          style: GoogleFonts.poppins(color: _valueColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user['userEmail'] != null)
                          Text(user['userEmail'], style: GoogleFonts.poppins(color: _labelColor, fontSize: 12)),
                        Text("Reason: ${user['reason'] ?? 'No reason provided'}", style: GoogleFonts.poppins(color: global.errorColor, fontSize: 12)),
                      ],
                    ),
                    trailing: _isSelectionMode 
                      ? null 
                      : IconButton(
                          icon: const Icon(Icons.person_add_rounded, color: global.successColor),
                          onPressed: () => _confirmUnban(user),
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
        title: Text("Unblock ${user['userName'] ?? 'User'}?", style: const TextStyle(color: Colors.white)),
        content: const Text("This user will be able to take the quiz again.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.successColor, foregroundColor: Colors.black),
            onPressed: () async {
              try {
                await DatabaseService().unbanUser(
                  userId: user['userId'],
                  quizId: widget.quizId,
                  adminId: FirebaseAuth.instance.currentUser!.uid,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User unblocked successfully")));
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Unblock"),
          ),
        ],
      ),
    );
  }
}

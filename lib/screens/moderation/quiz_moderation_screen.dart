import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

import '../../utils/global.dart' as global;

class QuizModerationScreen extends StatefulWidget {
  final String quizId;

  const QuizModerationScreen({super.key, required this.quizId});

  @override
  State<QuizModerationScreen> createState() => _QuizModerationScreenState();
}

class _QuizModerationScreenState extends State<QuizModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleBulkAction() async {
    if (_selectedIds.isEmpty) return;

    final bool isBannedTab = _tabController.index == 0;
    final String title = isBannedTab
        ? "Unblock Selected?"
        : "Recover Selected?";
    final String content = isBannedTab
        ? "These users will be allowed to take the quiz again."
        : "These responses will be restored to active status.";

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.successColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isBannedTab ? "UNBLOCK" : "RECOVER",
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = DatabaseService();
      final adminId = FirebaseAuth.instance.currentUser!.uid;

      try {
        if (isBannedTab) {
          for (String id in _selectedIds) {
            // In banned users tab, the ID is quizId_userId.
            final userId = id.split('_').last;
            await db.unbanUser(
              userId: userId,
              quizId: widget.quizId,
              adminId: adminId,
            );
          }
        } else {
          for (String id in _selectedIds) {
            await db.restoreResponse(responseId: id, quizId: widget.quizId);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${_selectedIds.length} items processed")),
          );
          setState(() {
            _selectedIds.clear();
            _isSelectionMode = false;
          });
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
                  _selectedIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedIds.length} Selected",
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                "Moderation Panel",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _valueColor,
                ),
              ),
        iconTheme: IconThemeData(color: _valueColor),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(
                    _tabController.index == 0
                        ? Icons.person_add_rounded
                        : Icons.restore_rounded,
                    color: global.successColor,
                  ),
                  onPressed: _handleBulkAction,
                ),
              ]
            : [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryAccent,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: "BLOCKED USERS", icon: Icon(Icons.person_off_rounded)),
            Tab(text: "DELETED DATA", icon: Icon(Icons.delete_sweep_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBannedUsersTab(), _buildDeletedResponsesTab()],
      ),
    );
  }

  Widget _buildBannedUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService().getQuizBannedUsers(widget.quizId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final bannedUsers = snapshot.data ?? [];
        if (bannedUsers.isEmpty) {
          return _buildEmptyState(Icons.block_rounded, "No blocked users");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bannedUsers.length,
          itemBuilder: (context, index) {
            final user = bannedUsers[index];
            final String id = user['id'];
            final bool isSelected = _selectedIds.contains(id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryAccent.withOpacity(0.2)
                    : _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primaryAccent : _borderColor,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  onLongPress: () => _toggleSelection(id),
                  onTap: _isSelectionMode ? () => _toggleSelection(id) : null,
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: _borderColor,
                        backgroundImage: user['userPhoto'] != null
                            ? NetworkImage(user['userPhoto'])
                            : null,
                        child: user['userPhoto'] == null
                            ? Icon(Icons.person, color: _labelColor)
                            : null,
                      ),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: global.primaryAccent,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['userName'] ?? "Unknown User",
                          style: GoogleFonts.poppins(
                            color: _valueColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "UID: ${user['userId']}",
                        style: GoogleFonts.poppins(
                          color: _labelColor,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        "Reason: ${user['reason'] ?? 'No reason'}",
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
                          icon: const Icon(
                            Icons.person_add_rounded,
                            color: global.successColor,
                          ),
                          onPressed: () => _confirmUnban(user),
                          tooltip: "Unblock User",
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeletedResponsesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService().getQuizResponses(
        widget.quizId,
        includeDeleted: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final responses = (snapshot.data ?? [])
            .where((r) => r['isDeleted'] == true)
            .toList();

        if (responses.isEmpty) {
          return _buildEmptyState(
            Icons.auto_delete_rounded,
            "No deleted responses found",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: responses.length,
          itemBuilder: (context, index) {
            final r = responses[index];
            final String id = r['id'];
            final bool isSelected = _selectedIds.contains(id);
            final actor = r['deletedByType'] ?? 'Admin';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryAccent.withOpacity(0.2)
                    : _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primaryAccent : _borderColor,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  onLongPress: () => _toggleSelection(id),
                  onTap: _isSelectionMode
                      ? () => _toggleSelection(id)
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultScreen(
                                quizId: r['quizId'],
                                attemptAnswers:
                                    r['answers'] as Map<String, dynamic>,
                                attemptReviewItems:
                                    r['reviewItems'] as List<dynamic>?,
                              ),
                            ),
                          );
                        },
                  title: Row(
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          "User: ${r['userId']}",
                          style: GoogleFonts.poppins(
                            color: _valueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Deleted By: ${actor.toString().toUpperCase()}",
                        style: const TextStyle(
                          color: global.errorColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Reason: ${r['deleteReason'] ?? 'N/A'}",
                        style: TextStyle(color: _labelColor, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: _isSelectionMode
                      ? null
                      : const Icon(
                          Icons.chevron_right,
                          color: global.errorColor,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: _borderColor),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.poppins(color: _labelColor)),
        ],
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
                await DatabaseService().unbanUser(
                  userId: user['userId'],
                  quizId: widget.quizId,
                  adminId: FirebaseAuth.instance.currentUser!.uid,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User unblocked successfully")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to unblock: $e")),
                  );
                }
              }
            },
            child: const Text("Unblock"),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

import '../../utils/global.dart' as global;
import 'colab/add_collaborator_screen.dart';
import 'colab/quiz_status_panel.dart';
import 'colab/team_list_panel.dart';

class QuizCollaboratorsScreen extends StatefulWidget {
  final String quizId;

  const QuizCollaboratorsScreen({super.key, required this.quizId});

  @override
  State<QuizCollaboratorsScreen> createState() =>
      _QuizCollaboratorsScreenState();
}

class _QuizCollaboratorsScreenState extends State<QuizCollaboratorsScreen> {
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isAdmin = false;
  bool _isOwner = false;
  bool _canManageThisTeam = false;
  bool _canLockUnlock = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Manage Quiz",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        iconTheme: const IconThemeData(color: global.valueColor),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quizzes')
            .doc(widget.quizId)
            .snapshots(),
        builder: (context, quizSnapshot) {
          final quizData = quizSnapshot.data?.data() as Map<String, dynamic>?;
          final bool isLocked = quizData?['isLocked'] ?? false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Quiz Status"),
              const SizedBox(height: 12),
              QuizStatusPanel(
                quizId: widget.quizId,
                isLocked: isLocked,
                canLockUnlock: _canLockUnlock,
                isAdmin: _isAdmin,
                currentUserId: _currentUserId,
              ),
              const SizedBox(height: 32),

              _buildSectionHeader("Current Team"),
              if (_canManageThisTeam)
                const SizedBox(height: 8)
              else
                const SizedBox(height: 12),
              
              if (_canManageThisTeam)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddCollaboratorScreen(
                          quizId: widget.quizId,
                          isAdmin: _isAdmin,
                          currentUserId: _currentUserId,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: global.primaryAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: global.primaryAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_outlined,
                              color: global.primaryAccent, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "Add New Collaborator",
                            style: GoogleFonts.poppins(
                              color: global.primaryAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              color: global.primaryAccent, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),

              TeamListPanel(
                quizId: widget.quizId,
                canManageThisTeam: _canManageThisTeam,
                currentUserId: _currentUserId,
                isAdmin: _isAdmin,
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          );
        },
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
}

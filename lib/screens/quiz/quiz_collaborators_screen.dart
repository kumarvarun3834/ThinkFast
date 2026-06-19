import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizCollaboratorsScreen extends StatefulWidget {
  final String quizId;

  const QuizCollaboratorsScreen({super.key, required this.quizId});

  @override
  State<QuizCollaboratorsScreen> createState() => _QuizCollaboratorsScreenState();
}

class _QuizCollaboratorsScreenState extends State<QuizCollaboratorsScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Permissions for the new manager
  bool _canUpdateData = true;
  bool _canSeeResponses = true;
  bool _canModerate = false;

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
          'canUpdateData': _canUpdateData,
          'canSeeResponses': _canSeeResponses,
          'canModerate': _canModerate,
        },
        addedBy: _currentUserId!,
      );
      _userIdController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Collaborator added successfully")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Collaborators",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _valueColor),
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
                  _buildPermissionSwitch("Update Quiz Data", _canUpdateData, (v) => setState(() => _canUpdateData = v)),
                  _buildPermissionSwitch("See Responses", _canSeeResponses, (v) => setState(() => _canSeeResponses = v)),
                  _buildPermissionSwitch("Moderate (Ban/Delete)", _canModerate, (v) => setState(() => _canModerate = v)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _addCollaborator,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("GRANT ACCESS", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  return Center(child: Text("No collaborators yet", style: TextStyle(color: _labelColor)));
                }

                return ListView.builder(
                  itemCount: managers.length,
                  itemBuilder: (context, index) {
                    final m = managers[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: ListTile(
                        title: Text(m['userId'], style: TextStyle(color: _valueColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "Perms: ${m['permissions']}",
                          style: TextStyle(color: _labelColor, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          onPressed: () async {
                            // Implementation of remove access
                          },
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

  Widget _buildPermissionSwitch(String title, bool value, Function(bool) onChanged) {
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

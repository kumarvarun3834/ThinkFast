import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

class MyAttemptsScreen extends StatefulWidget {
  const MyAttemptsScreen({super.key});

  @override
  State<MyAttemptsScreen> createState() => _MyAttemptsScreenState();
}

class _MyAttemptsScreenState extends State<MyAttemptsScreen> {
  User? _user;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Colors (Synced with Global Palette)
  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    final DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MY ATTEMPTS",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
      ),
      drawer: Drawer(
        backgroundColor: _cardColor,
        child: SidebarMenu(user: _user),
      ),
      body: _user == null
          ? Center(
              child: Text(
                "Please login to see your attempts",
                style: GoogleFonts.poppins(color: _labelColor),
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService().getUserAttempts(_user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: global.primaryAccent,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: _borderColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No attempts found",
                          style: GoogleFonts.poppins(color: _labelColor),
                        ),
                      ],
                    ),
                  );
                }

                final attempts = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    final int score = attempt['score'] ?? 0;
                    final int total = (attempt['totalQuestions'] ?? 0) * 4;
                    final int status = attempt['status'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderColor),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultScreen(
                                quizId: attempt['quizId'],
                                attemptAnswers:
                                    attempt['answers'] as Map<String, dynamic>,
                                attemptReviewItems:
                                    attempt['reviewItems'] as List<dynamic>?,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      attempt['quizTitle'] ?? "Untitled Quiz",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _valueColor,
                                      ),
                                    ),
                                  ),
                                  if (status == 1)
                                    const StatusBadge(
                                      text: "LOCKED",
                                      color: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    color: _primaryAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Score: $score / $total",
                                    style: GoogleFonts.poppins(
                                      color: score >= (total / 2)
                                          ? global.successColor
                                          : global.errorColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(attempt['timestamp']),
                                    style: GoogleFonts.poppins(
                                      color: _labelColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                color: global.borderColor,
                                height: 24,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _confirmDelete(attempt),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text("Delete"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: global.errorColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: status == 1
                                        ? null
                                        : () {
                                            // Handle edit if allowed
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Editing is disabled for locked attempts",
                                                ),
                                              ),
                                            );
                                          },
                                    icon: Icon(
                                      status == 1
                                          ? Icons.lock_outline
                                          : Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      status == 1 ? "Locked" : "Edit Attempt",
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: status == 1
                                          ? _labelColor
                                          : _primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  void _confirmDelete(Map<String, dynamic> attempt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          "Delete Attempt?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This attempt will be removed from your history. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await DatabaseService().softDeleteResponse(
                  responseId: attempt['id'],
                  quizId: attempt['quizId'],
                  actorId: _user!.uid,
                  reason: "User deleted own attempt",
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Attempt moved to trash (Soft Delete)"),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/result_screen.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class QuizResponsesScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizResponsesScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizResponsesScreen> createState() => _QuizResponsesScreenState();
}

class _QuizResponsesScreenState extends State<QuizResponsesScreen> {
  String _searchUserId = "";
  final TextEditingController _searchController = TextEditingController();

  // Colors (consistent with project)
  final Color _bgColor = const Color(0xFF0F172A);
  final Color _cardColor = const Color(0xFF1E293B);
  final Color _primaryAccent = const Color(0xFF3B82F6);
  final Color _valueColor = const Color(0xFFE2E8F0);
  final Color _labelColor = const Color(0xFF94A3B8);
  final Color _borderColor = const Color(0xFF334155);

  void _showModerationOptions(
    BuildContext context,
    Map<String, dynamic> response,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.redAccent,
            ),
            title: const Text(
              "Soft Delete Response",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              _confirmAction("Soft delete this response?", () async {
                await DatabaseService().softDeleteResponse(
                  responseId: response['id'],
                  quizId: widget.quizId,
                  adminId: FirebaseAuth.instance.currentUser!.uid,
                  reason: "Moderated by Admin",
                );
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_flipped, color: Colors.redAccent),
            title: const Text(
              "Ban User from Quiz",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              _confirmAction("Ban user ${response['userId']}?", () async {
                await DatabaseService().banUser(
                  userId: response['userId'],
                  quizId: widget.quizId,
                  reason: "Banned by Admin",
                  adminId: FirebaseAuth.instance.currentUser!.uid,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  void _confirmAction(String title, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await action();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
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
        title: Text(
          "Responses: ${widget.quizTitle}",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _valueColor,
          ),
        ),
        iconTheme: IconThemeData(color: _valueColor),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person_off_outlined,
              color: Colors.redAccent,
            ),
            onPressed: () {
              // Navigation to Banned Users screen if I had one
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Banned Users list coming soon..."),
                ),
              );
            },
            tooltip: "View Banned Users",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchUserId = value.trim();
                });
              },
              style: GoogleFonts.poppins(color: _valueColor),
              decoration: InputDecoration(
                hintText: "Filter by User ID",
                hintStyle: GoogleFonts.poppins(color: _labelColor),
                prefixIcon: Icon(Icons.search, color: _labelColor),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _borderColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DatabaseService().getQuizResponses(widget.quizId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "No responses yet",
                      style: GoogleFonts.poppins(color: _labelColor),
                    ),
                  );
                }

                var responses = snapshot.data!;

                // Filter by User ID if search text is not empty
                if (_searchUserId.isNotEmpty) {
                  responses = responses
                      .where(
                        (r) => (r['userId'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_searchUserId.toLowerCase()),
                      )
                      .toList();
                }

                // 1. Determine attempt numbers by sorting by timestamp ASC first
                responses.sort((a, b) {
                  final tA =
                      (a['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final tB =
                      (b['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return tA.compareTo(tB);
                });

                Map<String, List<Map<String, dynamic>>> groupedResponses = {};
                for (var r in responses) {
                  final uid = r['userId'] ?? 'Unknown';
                  groupedResponses.putIfAbsent(uid, () => []).add(r);
                }

                List<Map<String, dynamic>> flatResponses = [];
                groupedResponses.forEach((uid, userResponses) {
                  for (int i = 0; i < userResponses.length; i++) {
                    userResponses[i]['attemptNumber'] = i + 1;
                    flatResponses.add(userResponses[i]);
                  }
                });

                // 2. Sort as requested: "attempt 1 considered top for all"
                // This means sort by attemptNumber first, then maybe score or userId
                flatResponses.sort((a, b) {
                  int cmp = a['attemptNumber'].compareTo(b['attemptNumber']);
                  if (cmp == 0) {
                    // Within same attempt number, sort by score descending
                    int scoreA = a['score'] ?? 0;
                    int scoreB = b['score'] ?? 0;
                    return scoreB.compareTo(scoreA);
                  }
                  return cmp;
                });

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: flatResponses.length,
                        itemBuilder: (context, index) {
                          final r = flatResponses[index];
                          final score = r['score'] ?? 0;
                          final total = (r['totalQuestions'] ?? 0) * 4;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor),
                            ),
                            child: ListTile(
                              onTap: () {
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
                              onLongPress: () {
                                _showModerationOptions(context, r);
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "User ID: ${r['userId']}",
                                      style: GoogleFonts.poppins(
                                        color: _valueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (r['isDeleted'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      child: const Text(
                                        "DELETED",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _primaryAccent.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: _primaryAccent,
                                          ),
                                        ),
                                        child: Text(
                                          "Attempt #${r['attemptNumber']}",
                                          style: GoogleFonts.poppins(
                                            color: _primaryAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Score: $score / $total",
                                        style: GoogleFonts.poppins(
                                          color: score >= (total / 2)
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Date: ${_formatDate(r['timestamp'])}",
                                    style: GoogleFonts.poppins(
                                      color: _labelColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: _labelColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        border: Border(top: BorderSide(color: _borderColor)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TOTAL ATTEMPTS",
                              style: GoogleFonts.poppins(
                                color: _labelColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              "${flatResponses.length}",
                              style: GoogleFonts.poppins(
                                color: _primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

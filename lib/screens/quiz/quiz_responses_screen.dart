import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

import '../../utils/global.dart' as global;

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

  // Selection Logic
  final Set<String> _selectedResponseIds = {};
  bool _isSelectionMode = false;

  // Colors
  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedResponseIds.contains(id)) {
        _selectedResponseIds.remove(id);
        if (_selectedResponseIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedResponseIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleBulkAction(String action) async {
    if (_selectedResponseIds.isEmpty) return;

    final String title = action == 'delete'
        ? "Delete Selected?"
        : "Ban Selected?";
    final String content = action == 'delete'
        ? "These responses will be moved to the trash."
        : "These users will be blocked from this quiz.";

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
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = DatabaseService();
      final actorId = FirebaseAuth.instance.currentUser!.uid;

      try {
        // Need to fetch current list to get UserIDs if banning
        final responses = await db.getQuizResponses(widget.quizId).first;

        for (String id in _selectedResponseIds) {
          if (action == 'delete') {
            await db.softDeleteResponse(
              responseId: id,
              quizId: widget.quizId,
              actorId: actorId,
              reason: "Bulk moderated by Manager",
            );
          } else {
            final resp = responses.firstWhere((r) => r['id'] == id);
            await db.banUser(
              userId: resp['userId'],
              quizId: widget.quizId,
              reason: "Bulk banned by Manager",
              adminId: actorId,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${_selectedResponseIds.length} items processed"),
            ),
          );
          setState(() {
            _selectedResponseIds.clear();
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
              color: global.errorColor,
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
                  actorId: FirebaseAuth.instance.currentUser!.uid,
                  reason: "Moderated by Manager",
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Response moved to trash (Soft Delete)"),
                    ),
                  );
                }
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_flipped, color: global.errorColor),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User banned from quiz")),
                  );
                }
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
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedResponseIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedResponseIds.length} Selected",
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                "Responses: ${widget.quizTitle}",
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
                    Icons.delete_sweep_rounded,
                    color: global.errorColor,
                  ),
                  onPressed: () => _handleBulkAction('delete'),
                  tooltip: "Delete Selected",
                ),
                IconButton(
                  icon: const Icon(
                    Icons.block_flipped,
                    color: global.errorColor,
                  ),
                  onPressed: () => _handleBulkAction('ban'),
                  tooltip: "Ban Selected Users",
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(
                    Icons.person_off_outlined,
                    color: global.errorColor,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/Blocked Users',
                      arguments: widget.quizId,
                    );
                  },
                  tooltip: "View Banned Users",
                ),
              ],
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
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
                  hintText: "Filter by User, ID, or Marks...",
                  hintStyle: GoogleFonts.poppins(color: _labelColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: _labelColor, size: 20),
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
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

                // 1. Sort by time ASC to calculate attempt numbers correctly
                responses.sort((a, b) {
                  final tA =
                      (a['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final tB =
                      (b['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return tA.compareTo(tB);
                });

                // 2. Group by user and assign attempt numbers
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

                // 3. Filter based on multi-match: Name > UserID > Marks
                if (_searchUserId.isNotEmpty) {
                  final filter = _searchUserId.toLowerCase();
                  flatResponses = flatResponses.where((r) {
                    final name = (r['userName'] ?? '').toString().toLowerCase();
                    final uid = (r['userId'] ?? '').toString().toLowerCase();
                    final id = (r['id'] ?? '').toString().toLowerCase();
                    final score = (r['score'] ?? '').toString();
                    
                    return name.contains(filter) || 
                           uid.contains(filter) ||
                           id.contains(filter) || 
                           score.contains(filter);
                  }).toList();
                }

                // 4. Sort by time DESC for display (Newest first)
                flatResponses.sort((a, b) {
                  final tA =
                      (a['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final tB =
                      (b['timestamp'] as dynamic)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  itemCount: flatResponses.length,
                  itemBuilder: (context, index) {
                    final r = flatResponses[index];
                    final String id = r['id'];
                    final bool isSelected = _selectedResponseIds.contains(id);
                    final score = r['score'] ?? 0;
                    final total = (r['totalQuestions'] ?? 0) * 4;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(id)
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResultScreen(
                                        quizId: r['quizId'],
                                        attemptAnswers:
                                            r['answers']
                                                as Map<String, dynamic>,
                                        attemptReviewItems:
                                            r['reviewItems'] as List<dynamic>?,
                                        attemptQuestionOrder: r['questionOrder'] as List<dynamic>?,
                                      ),
                                    ),
                                  );
                                },
                          title: Row(
                            children: [
                              if (_isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? _primaryAccent
                                        : _labelColor,
                                    size: 20,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  r['userName'] ?? "User: ${r['userId']}",
                                  style: GoogleFonts.poppins(
                                    color: _valueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (r['userId'] ==
                                  FirebaseAuth.instance.currentUser?.uid)
                                const StatusBadge(
                                  text: "OWNER",
                                  color: global.primaryAccent,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                ),
                              if (r['isDeleted'] == true)
                                const StatusBadge(
                                  text: "DELETED",
                                  color: global.errorColor,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("User ID: ${r['userId']}", style: TextStyle(color: _labelColor, fontSize: 10)),
                              Text("ID: $id", style: TextStyle(color: _labelColor, fontSize: 10, fontFamily: 'monospace')),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  StatusBadge(
                                    text: "Attempt #${r['attemptNumber']}",
                                    color: _primaryAccent,
                                    fontSize: 11,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (score >= total / 2 ? global.successColor : global.errorColor).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Marks: $score / $total",
                                      style: GoogleFonts.poppins(
                                        color: score >= (total / 2)
                                            ? global.successColor
                                            : global.errorColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Date: ${_formatDate(r['timestamp'])}",
                                style: GoogleFonts.poppins(
                                  color: _labelColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: _isSelectionMode
                              ? null
                              : Icon(Icons.chevron_right, color: _labelColor),
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
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/text_container.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/widgets/quiz_widgets.dart';

class MyAttemptsScreen extends StatefulWidget {
  final String? quizId;
  const MyAttemptsScreen({super.key, this.quizId});

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
              stream: global.db.getUserAttempts(_user!.uid, includeDeleted: true),
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

                final allAttempts = snapshot.data!;
                final attempts = widget.quizId == null 
                    ? allAttempts 
                    : allAttempts.where((a) => a['quizId'] == widget.quizId).toList();

                if (attempts.isEmpty) {
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
                          widget.quizId == null ? "No attempts found" : "No attempts for this quiz found",
                          style: GoogleFonts.poppins(color: _labelColor),
                        ),
                      ],
                    ),
                  );
                }

                int totalAggScore = 0;
                int totalAggQuestions = 0;
                for (var a in attempts) {
                  totalAggScore += (a['score'] as int? ?? 0);
                  totalAggQuestions += ((a['totalQuestions'] as int? ?? 0) * 4);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: attempts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          Card(
                            color: _cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: _borderColor),
                            ),
                            child: MarksPanel(
                              totalCorrectAnswers: totalAggScore,
                              totalQuestions: totalAggQuestions,
                              title: "Overall Performance",
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                              child: Text(
                                "RECENT ATTEMPTS",
                                style: GoogleFonts.poppins(
                                  color: _primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final attempt = attempts[index - 1];
                    return ModularAttemptCard(
                      attempt: attempt,
                      user: _user!,
                      onDelete: () => _confirmDelete(attempt),
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await global.qDb.softDeleteResponse(
                  responseId: attempt['id'],
                  quizId: attempt['quizId'],
                  actorId: _user!.uid,
                  reason: "User deleted own attempt",
                );
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Attempt moved to trash (Soft Delete)"),
                  ),
                );
              } catch (e) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

class ModularAttemptCard extends StatefulWidget {
  final Map<String, dynamic> attempt;
  final User user;
  final VoidCallback onDelete;

  const ModularAttemptCard({
    super.key,
    required this.attempt,
    required this.user,
    required this.onDelete,
  });

  @override
  State<ModularAttemptCard> createState() => _ModularAttemptCardState();
}

class _ModularAttemptCardState extends State<ModularAttemptCard> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _calculatedResults = [];
  Map<String, List<Map<String, dynamic>>> _moduleGroups = {};
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModularData();
  }

  Future<void> _loadModularData() async {
    if (_isDataLoaded) return;
    setState(() => _isLoading = true);

    try {
      final quizId = widget.attempt['quizId'];
      final userAnswers = widget.attempt['answers'] as Map<String, dynamic>;
      final reviewUids = widget.attempt['reviewItems'] != null
          ? List<String>.from(widget.attempt['reviewItems'])
          : <String>[];
      final visitedUids = widget.attempt['visitedItems'] != null
          ? List<String>.from(widget.attempt['visitedItems'])
          : <String>[];

      // Fetch Quiz & Answers
      final quiz = await global.db.readDatabase(quizId, userId: widget.user.uid);
      final response = await global.db.getQuizAnswers(quizId, widget.user.uid);
      final correctAnswers = response['answers'];
      final markingScheme = quiz['markingScheme'] ?? {"type": "default"};

      final List<Map<String, dynamic>> allQuestions = [];
      final List<dynamic> rawModules = quiz['modules'] as List? ?? [];
      for (var module in rawModules) {
        final String subject = module['subject']?.toString() ?? 'General';
        final List<dynamic> moduleData = module['data'] as List? ?? [];
        for (var q in moduleData) {
          final qMap = Map<String, dynamic>.from(q);
          qMap['subject'] = subject; // Inject subject into question
          allQuestions.add(qMap);
        }
      }

      // Reorder based on questionOrder if available
      final List<String> questionOrder = widget.attempt['questionOrder'] != null
          ? List<String>.from(widget.attempt['questionOrder'])
          : <String>[];

      List<Map<String, dynamic>> displayQuizData = [];
      if (questionOrder.isNotEmpty) {
        for (var qUid in questionOrder) {
          try {
            final q = allQuestions.firstWhere(
              (element) =>
                  (element['Q']?['id'] ?? element['uid']).toString() == qUid,
            );
            displayQuizData.add(q);
          } catch (_) {}
        }
      } else {
        displayQuizData = allQuestions;
      }

      Map<String, int> getMarking(String? type, String qUid) {
        final schemeType = markingScheme['type'] ?? 'default';
        if (schemeType == 'entire_quiz') {
          return {
            'correct': (markingScheme['global']?['correct'] ?? 4).toInt(),
            'wrong': (markingScheme['global']?['wrong'] ?? -1).toInt(),
          };
        } else if (schemeType == 'per_question_type') {
          final pqt = markingScheme['perQuestionType'] as Map? ?? {};
          final config =
              pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
          return {
            'correct': (config['correct'] ?? 4).toInt(),
            'wrong': (config['wrong'] ?? -1).toInt(),
          };
        } else if (schemeType == 'per_question') {
          final pq = markingScheme['perQuestion'] as Map? ?? {};
          final config = pq[qUid] ?? {'correct': 4, 'wrong': -1};
          return {
            'correct': (config['correct'] ?? 4).toInt(),
            'wrong': (config['wrong'] ?? -1).toInt(),
          };
        }
        return {'correct': 4, 'wrong': -1};
      }

      _calculatedResults = [];
      for (var q in displayQuizData) {
        final qUid = (q['Q']?['id'] ?? q['uid']).toString();
        final selections = userAnswers[qUid] is List
            ? List<String>.from(userAnswers[qUid])
            : (userAnswers[qUid] != null
                ? [userAnswers[qUid].toString()]
                : <String>[]);

        final answers = correctAnswers[qUid] ?? [];
        final String? qType = q['type'];
        final String qSubject = q['subject']?.toString() ?? 'General';
        final marking = getMarking(qType, qUid);

        int questionMark = 0;
        if (selections.isEmpty) {
          questionMark = 0;
        } else {
          bool isCorrect = false;
          if (qType == "Integer") {
            final String userVal = selections.first.trim();
            final String correctVal =
                answers.isNotEmpty ? answers.first.trim() : "";
            isCorrect = userVal == correctVal;
          } else {
            isCorrect = selections.length == answers.length &&
                selections.every((s) => answers.contains(s));
          }
          questionMark = isCorrect ? marking['correct']! : marking['wrong']!;
        }

        _calculatedResults.add({
          'uid': qUid,
          'mark': questionMark,
          'selections': selections,
          'subject': qSubject,
          'isReview': reviewUids.contains(qUid),
          'isVisited': visitedUids.contains(qUid),
        });
      }

      _moduleGroups = {};
      for (var res in _calculatedResults) {
        final subject = res['subject'] ?? 'General';
        _moduleGroups.putIfAbsent(subject, () => []).add(res);
      }

      _isDataLoaded = true;
    } catch (e) {
      debugPrint("Error loading modular data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int score = widget.attempt['score'] ?? 0;
    final int total = (widget.attempt['totalQuestions'] ?? 0) * 4;
    final int status = widget.attempt['status'] ?? 0;
    final String quizId = widget.attempt['quizId'];
    
    // Check permission: Owner of the quiz OR App Admin
    final bool isOwner = global.ownedQuizIds.contains(quizId);
    final bool canDelete = isOwner || global.isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.attempt['isDeleted'] == true
            ? global.errorColor.withOpacity(0.05)
            : global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.attempt['isDeleted'] == true
              ? global.errorColor.withOpacity(0.3)
              : global.borderColor,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                quizId: widget.attempt['quizId'],
                attemptAnswers:
                    widget.attempt['answers'] as Map<String, dynamic>,
                attemptReviewItems:
                    widget.attempt['reviewItems'] as List<dynamic>?,
                attemptQuestionOrder:
                    widget.attempt['questionOrder'] as List<dynamic>?,
                attemptVisitedItems:
                    widget.attempt['visitedItems'] as List<dynamic>?,
                isDeleted: widget.attempt['isDeleted'] == true,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.attempt['quizTitle'] ?? "Untitled Quiz",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.attempt['isDeleted'] == true
                            ? global.errorColor.withOpacity(0.8)
                            : global.valueColor,
                      ),
                    ),
                  ),
                  if (widget.attempt['isDeleted'] == true)
                    const StatusBadge(
                      text: "DELETED",
                      color: global.errorColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    )
                  else if (status == 1)
                    const StatusBadge(
                      text: "COMPLETED",
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
                    color: global.primaryAccent,
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
                    _formatDate(widget.attempt['timestamp']),
                    style: GoogleFonts.poppins(
                      color: global.labelColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (!_isDataLoaded && _isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: global.primaryAccent,
                      ),
                    ),
                  ),
                )
              else if (_isDataLoaded) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _calculatedResults.length,
                    itemBuilder: (context, idx) {
                      final res = _calculatedResults[idx];
                      return Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildQuestionStatusDot(res, idx + 1),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _moduleGroups.entries.map((e) {
                    final String name = e.key;
                    final List<Map<String, dynamic>> group = e.value;
                    int correct = 0;
                    for (var res in group) {
                      if (res['mark'] > 0) correct++;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: global.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$name: $correct/${group.length}",
                        style: GoogleFonts.poppins(
                          color: global.primaryAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Divider(
                color: global.borderColor,
                height: 24,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canDelete)
                    TextButton.icon(
                      onPressed: widget.onDelete,
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultScreen(
                            quizId: widget.attempt['quizId'],
                            attemptAnswers:
                                widget.attempt['answers'] as Map<String, dynamic>,
                            attemptReviewItems:
                                widget.attempt['reviewItems'] as List<dynamic>?,
                            attemptQuestionOrder:
                                widget.attempt['questionOrder'] as List<dynamic>?,
                            attemptVisitedItems:
                                widget.attempt['visitedItems'] as List<dynamic>?,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                    ),
                    label: const Text("Review Attempt"),
                    style: TextButton.styleFrom(
                      foregroundColor: global.primaryAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionStatusDot(Map<String, dynamic> res, int displayIndex) {
    final mark = res['mark'] as int;
    final selections = res['selections'] as List;
    final bool isReview = res['isReview'] ?? false;
    final bool isAnswered = selections.isNotEmpty;
    final bool isVisited = res['isVisited'] ?? true;

    bool isCorrect = isAnswered && mark > 0;
    bool isWrong = isAnswered && mark <= 0;

    if (isReview) {
      List<Color> gradientColors = [global.reviewColor, Colors.grey];
      if (isCorrect) {
        gradientColors = [global.reviewColor, Colors.green];
      } else if (isWrong) {
        gradientColors = [global.reviewColor, global.errorColor];
      } else if (isVisited) {
        gradientColors = [global.reviewColor, global.infoColor];
      }

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            displayIndex.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ),
      );
    }

    Color color = Colors.grey;
    if (isCorrect) {
      color = Colors.green;
    } else if (isWrong) {
      color = global.errorColor;
    } else if (isVisited) {
      color = global.infoColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          displayIndex.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    final DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}

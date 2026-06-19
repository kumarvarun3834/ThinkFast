import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/services/firebase_direct_commands.dart';

class ResultScreen extends StatefulWidget {
  final String? quizId;
  final Map<String, dynamic>? attemptAnswers;

  const ResultScreen({super.key, this.quizId, this.attemptAnswers});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int totalMarks = 0;
  int _maxMarks = 0;
  bool _isLoading = true;
  Map<String, List<String>> _correctAnswers = {};
  List<Map<String, dynamic>> _displayQuizData = [];
  List<Map<String, dynamic>> _calculatedResults = [];
  Map<String, dynamic> _markingScheme = {"type": "default"};
  String _quizId = "";

  @override
  void initState() {
    super.initState();
    _loadAnswersAndCalculateScore();
  }

  Future<void> _loadAnswersAndCalculateScore() async {
    try {
      final db = DatabaseService();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      Map<String, dynamic> userAnswers = {};
      List<List<dynamic>> displayQuizResult = [];
      
      if (widget.quizId != null && widget.attemptAnswers != null) {
        // VIEWING PAST ATTEMPT
        _quizId = widget.quizId!;
        userAnswers = widget.attemptAnswers!;
        
        // Fetch quiz data (questions)
        final quiz = await db.readDatabase(_quizId, userId: user.uid);
        _displayQuizData = [];
        final List<dynamic> rawModules = quiz['modules'] as List? ?? [];
        for (var module in rawModules) {
          final List<dynamic> moduleData = module['data'] as List? ?? [];
          for (var q in moduleData) {
            _displayQuizData.add(Map<String, dynamic>.from(q));
          }
        }
        _markingScheme = quiz['markingScheme'] ?? {"type": "default"};
        
        // Build displayQuizResult from quiz data and userAnswers
        for (var q in _displayQuizData) {
          final qMap = q['Q'] as Map;
          final qId = qMap['id'].toString();
          final qText = qMap['text'].toString();
          final selections = userAnswers[qId] is List 
              ? List<String>.from(userAnswers[qId])
              : (userAnswers[qId] != null ? [userAnswers[qId].toString()] : <String>[]);
          
          displayQuizResult.add([qText, qId, selections]);
        }
        
        // Fetch correct answers (don't pass userAnswers to avoid resubmitting)
        _correctAnswers = await db.getQuizAnswers(_quizId, user.uid);
      } else {
        // JUST FINISHED QUIZ (Using Global)
        _quizId = global.ID;
        _displayQuizData = List<Map<String, dynamic>>.from(global.quizData);
        displayQuizResult = List<List<dynamic>>.from(global.quizResult);
        _markingScheme = global.markingScheme;

        for (var result in displayQuizResult) {
          final String qUid = result[1];
          final List<String> selections = (result[2] as List).cast<String>();
          userAnswers[qUid] = selections;
        }

        // Fetch answers and SUBMIT attempt in one call
        _correctAnswers = await db.getQuizAnswers(
          _quizId,
          user.uid,
          totalQuestions: displayQuizResult.length,
          userAnswers: userAnswers,
        );
      }

      int total = 0;
      int maxPoints = 0;
      _calculatedResults = [];
      
      // Helper to get marking for a question
      Map<String, int> getMarking(String? type, String qUid) {
        final schemeType = _markingScheme['type'] ?? 'default';
        if (schemeType == 'entire_quiz') {
          return {
            'correct': (_markingScheme['global']?['correct'] ?? 4).toInt(),
            'wrong': (_markingScheme['global']?['wrong'] ?? -1).toInt(),
          };
        } else if (schemeType == 'per_question_type') {
          final pqt = _markingScheme['perQuestionType'] as Map? ?? {};
          final config = pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
          return {
            'correct': (config['correct'] ?? 4).toInt(),
            'wrong': (config['wrong'] ?? -1).toInt(),
          };
        } else if (schemeType == 'per_question') {
          final pq = _markingScheme['perQuestion'] as Map? ?? {};
          final config = pq[qUid] ?? {'correct': 4, 'wrong': -1};
          return {
            'correct': (config['correct'] ?? 4).toInt(),
            'wrong': (config['wrong'] ?? -1).toInt(),
          };
        }
        return {'correct': 4, 'wrong': -1};
      }

      for (int i = 0; i < displayQuizResult.length; i++) {
        final List<dynamic> resultDataset = displayQuizResult[i];
        final String qText = resultDataset[0];
        final String qUid = resultDataset[1];
        final List<String> selections = (resultDataset[2] as List).cast<String>();

        // Find correct option UIDs
        final List<String> answers = _correctAnswers[qUid] ?? [];

        // Find question type
        String? qType;
        try {
          final qDoc = _displayQuizData.firstWhere((q) => (q['Q']?['id'] ?? q['uid']) == qUid);
          qType = qDoc['type'];
        } catch (_) {}

        final marking = getMarking(qType, qUid);
        maxPoints += marking['correct']!;

        int questionMark = 0;
        if (selections.isEmpty) {
          questionMark = 0;
        } else if (qType == "Integer") {
          final String userVal = selections.first.trim();
          final String correctVal = answers.isNotEmpty ? answers.first.trim() : "";
          if (userVal == correctVal) {
            questionMark = marking['correct']!;
          } else {
            questionMark = marking['wrong']!;
          }
        } else if (selections.length == answers.length &&
            selections.every((s) => answers.contains(s))) {
          questionMark = marking['correct']!;
        } else {
          questionMark = marking['wrong']!;
        }
        
        total += questionMark;
        
        _calculatedResults.add({
          'text': qText,
          'uid': qUid,
          'selections': selections,
          'answers': answers,
          'mark': questionMark,
          'type': qType,
        });
      }

      setState(() {
        totalMarks = total;
        _maxMarks = maxPoints;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching answers: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    List<Widget> resultWidgets = [];

    // 1. Marks Panel
    resultWidgets.add(Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.all(20),
      child: Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        child: Center(
          child: MarksPanel(
            totalCorrectAnswers: totalMarks,
            totalQuestions: _maxMarks,
          ),
        ),
      ),
    ));

    // 2. Action Buttons
    resultWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, "/home", (r) => false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFFE2E8F0),
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
              ),
              icon: const Icon(Icons.home_outlined),
              label: const Text("HOME"),
            ),
          ),
        ],
      ),
    ));

    resultWidgets.add(const SizedBox(height: 24));

    // 3. Detailed Results
    for (int i = 0; i < _calculatedResults.length; i++) {
      final res = _calculatedResults[i];
      final String qText = res['text'];
      final String qUid = res['uid'];
      final List<String> selections = res['selections'];
      final List<String> answers = res['answers'];
      final int questionMark = res['mark'];
      final String? qType = res['type'];

      // Find the text for these UIDs to show in UI
      final quizItem = _displayQuizData.firstWhere(
        (q) => (q['Q'] as Map)['id'] == qUid,
        orElse: () => {'Q': {'id': qUid, 'text': qText}, 'As': []},
      );
      final List<dynamic> options = quizItem['As'] as List? ?? [];

      String getOptText(String uid) {
        if (qType == "Integer") return uid;
        final opt = options.firstWhere(
          (o) => (o as Map)['id'] == uid,
          orElse: () => {'id': uid, 'text': "Option ID: $uid"},
        );
        return (opt as Map)['text'].toString();
      }

      resultWidgets.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Q${i + 1}: $qText",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE2E8F0),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Points:",
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      "${questionMark > 0 ? '+' : ''}$questionMark",
                      style: GoogleFonts.poppins(
                        color: questionMark > 0
                            ? Colors.greenAccent
                            : (questionMark < 0 ? Colors.redAccent : Colors.orangeAccent),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF334155), height: 32),
                Text(
                  "Correct Answer(s):",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...answers.map((a) => Text(
                  getOptText(a),
                  style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 16),
                )),
                const SizedBox(height: 12),
                Text(
                  "Your Selection:",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selections.isEmpty
                    ? Text("Not Answered", style: GoogleFonts.poppins(color: Colors.orangeAccent))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: selections.map((s) {
                          bool isCorrect = answers.contains(s);
                          return Text(
                            getOptText(s),
                            style: GoogleFonts.poppins(
                              color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 16,
                            ),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        ),
      ));
    }

    resultWidgets.add(const SizedBox(height: 40));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Result Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(children: resultWidgets),
      ),
    );
  }
}

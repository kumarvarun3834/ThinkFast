import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/services/firebase_direct_commands.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int totalMarks = 0;
  bool _isLoading = true;
  Map<String, List<String>> _correctAnswers = {};

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

      // Construct map of qUid -> selected optUids for submission
      final Map<String, dynamic> userAnswers = {};
      for (var result in global.quizResult) {
        final String qUid = result[1];
        final List<String> selections = (result[2] as List).cast<String>();
        userAnswers[qUid] = selections;
      }

      // Fetch answers and SUBMIT attempt in one call
      _correctAnswers = await db.getQuizAnswers(
        global.ID,
        user.uid,
        totalQuestions: global.quizResult.length,
        userAnswers: userAnswers,
      );

      int total = 0;
      for (int i = 0; i < global.quizResult.length; i++) {
        final List<dynamic> resultDataset = global.quizResult[i];
        final String qUid = resultDataset[1];
        final List<String> selections = (resultDataset[2] as List).cast<String>();

        // Find correct option UIDs
        final List<String> answers = _correctAnswers[qUid] ?? [];

        if (selections.isEmpty) {
          // No marks for skipped
        } else if (selections.length == answers.length &&
            selections.every((s) => answers.contains(s))) {
          total += 4; // Correct
        } else {
          total -= 1; // Wrong
        }
      }

      setState(() {
        totalMarks = total;
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
            totalQuestions: global.quizResult.length * 4,
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
    for (int i = 0; i < global.quizResult.length; i++) {
      final List<dynamic> resultDataset = global.quizResult[i];
      final String qText = resultDataset[0];
      final String qUid = resultDataset[1];
      final List<String> selections = (resultDataset[2] as List).cast<String>();
      final List<String> answers = _correctAnswers[qUid] ?? [];

      // Need to find the text for these UIDs to show in UI
      // global.quizData contains [{ Q:{id,text}, Opt:[{id,text}...] }]
      final quizItem = global.quizData.firstWhere((q) => (q['Q'] as Map)['id'] == qUid);
      final List<dynamic> options = quizItem['Opt'] as List;

      String getOptText(String uid) {
        final opt = options.firstWhere((o) => (o as Map)['id'] == uid, orElse: () => {'id': uid, 'text': "Unknown"});
        return (opt as Map)['text'].toString();
      }

      int questionMark = 0;
      if (selections.isEmpty) {
        questionMark = 0;
      } else if (selections.length == answers.length &&
          selections.every((s) => answers.contains(s))) {
        questionMark = 4;
      } else {
        questionMark = -1;
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

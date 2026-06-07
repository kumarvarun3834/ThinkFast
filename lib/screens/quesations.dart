import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/services/firebase_direct_commands.dart';

class Quesations extends StatefulWidget {
  const Quesations({super.key});

  @override
  State<Quesations> createState() => _Quesations();
}

class _Quesations extends State<Quesations> with WidgetsBindingObserver {
  int i = 0;
  Map<String, Object> currentData = {};
  Duration _timeLeft = Duration.zero; // ⏱️ dynamic time from Firestore
  Timer? _timer;
  DateTime? _lastBackPressTime;
  bool _isSubmitted = false;

  /// 🔀 Shuffle questions & choices
  void _shuffleQuestionsAndOptions() {
    final random = Random();
    global.quizData.shuffle(random);

    for (var q in global.quizData) {
      // Shuffle choices (Opt is [{id, text}, ...])
      final opts = (q["Opt"] as List?)?.toList() ?? [];
      opts.shuffle(random);
      q["Opt"] = opts;
    }

    // 2D Array format for Results (Application State): [ [qText, qUid, selectionList, visitedBool], ... ]
    global.quizResult = global.quizData.map((q) {
      final qInfo = q["Q"] as Map;
      final qUid = qInfo['id'].toString();
      final qText = qInfo['text'].toString();

      return [
        qText,
        qUid,
        <String>[], // Store selected optUids
        false,
      ];
    }).toList();
  }

  /// Reset quizResult with empty selections in 2D array format
  List<List<dynamic>> _quizReset(List<Map<String, Object>> quizData) {
    List<List<dynamic>> quizResult = [];
    for (var q in quizData) {
      final qInfo = q["Q"] as Map;
      quizResult.add([
        qInfo['text'].toString(), // text
        qInfo['id'].toString(), // uid
        <String>[], // selections
        false, // visited
      ]);
    }
    return quizResult;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hide status bar and navigation bar (Immersive Mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadQuizWithTime(); // fetch from Firestore
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore system UI when leaving
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detect when user tries to minimize app or use Home/Recent buttons
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        !_isSubmitted) {
      debugPrint("User attempted to leave the app. Auto-submitting quiz.");
      _submitAndFinish();
    }
  }

  Future<void> _loadQuizWithTime() async {
    // assume global.currentQuizId is set when quiz is chosen
    final int timeSeconds = global.time;

    _shuffleQuestionsAndOptions();

    setState(() {
      currentData = global.quizData[i];
      _timeLeft = Duration(seconds: timeSeconds.toInt()); // ⏱️ assign from DB
    });

    _startTimer();
  }

  Future<void> _submitAndFinish() async {
    if (_isSubmitted) return;
    _isSubmitted = true;

    setState(() => _timer?.cancel());

    // Restore system UI before navigating away
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      Navigator.pushReplacementNamed(context, "/Quiz Result");
    }
  }

  void switchToResultScreen() {
    _submitAndFinish();
  }

  void switchState() {
    setState(() {
      currentData = global.quizData[i];
      final qInfo = currentData["Q"] as Map;
      global.quizResult[i][0] = qInfo['text'].toString(); // question text
      global.quizResult[i][1] = qInfo['id'].toString(); // question uid
      global.quizResult[i][3] = true; // visited
    });
  }

  List<Widget> buttons_Data(Map<String, Object> quizData) {
    List<Widget> database = [];

    // Opt is [{id, text}, ...]
    final List<dynamic> options = quizData["Opt"] as List? ?? [];

    for (var option in options) {
      if (option is Map) {
        final String optUid = option['id'].toString();
        final String optText = option['text'].toString();

        database.add(
          buttons_opt(
            quizData["type"]?.toString() ?? "Single Choice",
            optUid,
            optText,
            switchState,
            global.quizResult[i],
          ),
        );
      }
    }
    return database;
  }

  List<Widget> menu_opt() {
    return [
      for (int j = 0; j < global.quizData.length; j++)
        GestureDetector(
          onTap: () {
            i = j;
            switchState();
            Navigator.pop(context); // Close the drawer
          },
          child: Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getQuestionColor(global.quizResult[j]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "${j + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  // ✅ safe selector (2D Array)
  List<String> _getSelection(List<dynamic> question) {
    final sel = question[2];
    if (sel is List) {
      return sel.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  Color _getQuestionColor(List<dynamic> question) {
    final selection = _getSelection(question);
    if (selection.isEmpty) return Colors.grey; // not visited
    return Colors.green;
  }

  String _format(Duration d) =>
      "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
      "${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft -= const Duration(seconds: 1);
        } else {
          t.cancel();
          switchToResultScreen();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Strictly prevent exiting via back button without submission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Exiting is disabled! You must SUBMIT the quiz to finish.",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: "SUBMIT NOW",
              textColor: Colors.white,
              onPressed: switchToResultScreen,
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Quiz",
            style: GoogleFonts.poppins(color: const Color(0xFFE2E8F0)),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFE2E8F0)),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: switchToResultScreen,
                child: const Text(
                  "SUBMIT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              color: const Color(0xFF1E293B),
              height: 30,
              alignment: Alignment.center,
              child: Text(
                _timer?.isActive == true
                    ? "⏳ Time left: ${_format(_timeLeft)}"
                    : "No active timer",
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
              ),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF1E293B),
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF0F172A)),
                child: Center(
                  child: Text(
                    'Questions',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFE2E8F0),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: menu_opt(),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Container(
          color: const Color(0xFF0F172A),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  width: double.infinity,
                  child: Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Question: ${(currentData["Q"] as Map?)?['text'] ?? ""}",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFE2E8F0),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.all(20),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(children: buttons_Data(currentData)),
                ),
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: const Color(0xFFE2E8F0),
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: i > 0
                          ? () {
                              i--;
                              switchState();
                            }
                          : null,
                      child: const Text("PREVIOUS"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: i < global.quizData.length - 1
                          ? () {
                              i++;
                              switchState();
                            }
                          : null,
                      child: const Text("NEXT"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class buttons_opt extends StatelessWidget {
  final VoidCallback onPressed;
  final String optUid;
  final String optText;
  final String type;
  final List<dynamic> quizResultChunk;

  buttons_opt(
    this.type,
    this.optUid,
    this.optText,
    this.onPressed,
    this.quizResultChunk, {
    super.key,
  });

  List<String> _getSelection() {
    final sel = quizResultChunk[2];
    if (sel is List) {
      return sel.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final selectionList = _getSelection();
    final bool isSelected = selectionList.contains(optUid);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: () {
          final sel = _getSelection();
          if (type == "Single Choice") {
            quizResultChunk[2] = [optUid];
          } else {
            if (sel.contains(optUid)) {
              sel.remove(optUid);
            } else {
              sel.add(optUid);
            }
            quizResultChunk[2] = sel;
          }
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.2)
              : const Color(0xFF1E293B),
          foregroundColor: isSelected
              ? const Color(0xFF3B82F6)
              : const Color(0xFFE2E8F0),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFF334155),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            optText,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

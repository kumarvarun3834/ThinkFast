import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;

class Quesations extends StatefulWidget {
  const Quesations({super.key});

  @override
  State<Quesations> createState() => _Quesations();
}

class _Quesations extends State<Quesations> {
  int i = 0;
  Map<String, Object> currentData = {};
  Duration _timeLeft = Duration.zero; // ⏱️ dynamic time from Firestore
  Timer? _timer;

  /// 🔀 Shuffle questions & choices
  void _shuffleQuestionsAndOptions() {
    final random = Random();
    global.quizData.shuffle(random);

    for (var q in global.quizData) {
      // Save answer values as List<String>
      List<String> answers = [];
      if (q["answer"] != null) {
        if (q["answer"] is List) {
          for (var e in q["answer"] as List) {
            if (e is int && q["choices"] != null) {
              answers.add((q["choices"] as List)[e].toString());
            } else {
              answers.add(e.toString());
            }
          }
        } else if (q["answer"] is int && q["choices"] != null) {
          answers.add((q["choices"] as List)[q["answer"] as int].toString());
        } else {
          answers.add(q["answer"].toString());
        }
      }
      q["answer"] = answers;

      // Shuffle choices
      final opts = (q["choices"] as List?)?.map((e) => e.toString()).toList() ?? [];
      opts.shuffle(random);
      q["choices"] = opts;
    }
  }

  /// Reset quizResult with empty selections
  List<Map<String, Object>> _quizReset(List<Map<String, Object>> quizData) {
    List<Map<String, Object>> quizResult = [];
    for (var q in quizData) {
      quizResult.add({
        "question": q["question"]?.toString() ?? "",
        "selection": <String>[],
        "visited": false,
        "answer": (q["answer"] as List?)?.cast<String>() ?? [],
      });
    }
    return quizResult;
  }

  @override
  void initState() {
    super.initState();
    _loadQuizWithTime(); // fetch from Firestore
  }

  Future<void> _loadQuizWithTime() async {
    // assume global.currentQuizId is set when quiz is chosen
    final int timeSeconds =global.time;
    // final int timeSeconds = (int.tryParse((global.quizData['time'] as String) ?? "1") ?? 1) * 60;

    global.quizResult = _quizReset(global.quizData);
    _shuffleQuestionsAndOptions();
    global.quizResult = _quizReset(global.quizData);

    setState(() {
      currentData = global.quizData[i];
      global.quizResult[i]["answer"] =
      global.quizData[i]["answer"] as List<String>;
      _timeLeft = Duration(seconds: timeSeconds.toInt()); // ⏱️ assign from DB
    });

    _startTimer();
  }

  void switchToResultScreen() {
    Navigator.pushNamed(context, "/Quiz Result");
  }

  void switchState() {
    setState(() {
      currentData = global.quizData[i];
      global.quizResult[i]["question"] =
          global.quizData[i]["question"].toString();
      global.quizResult[i]["answer"] =
          global.quizData[i]["answer"]?.toString() ?? "";
      global.quizResult[i]["visited"] = true;
    });
  }

  List<Widget> buttons_Data(Map<String, Object> quizData) {
    List<Widget> database = [];

    var rawChoices = quizData["choices"];
    List<String> options = [];
    if (rawChoices is List) {
      options = rawChoices.map((e) => e.toString()).toList();
    } else if (rawChoices is String) {
      options = rawChoices.split(",").map((e) => e.trim()).toList();
    }

    for (var option in options) {
      database.add(
        buttons_opt(
          quizData["type"]?.toString() ?? "Single Choice",
          option,
          switchState,
          global.quizResult[i],
        ),
      );
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

  // ✅ safe selector
  List<String> _getSelection(Map<String, Object> question) {
    final sel = question["selection"];
    if (sel is List) {
      return sel.map((e) => e.toString()).toList();
    } else if (sel is String && sel.isNotEmpty) {
      return [sel];
    }
    return <String>[];
  }

  Color _getQuestionColor(Map<String, Object> question) {
    final selection = _getSelection(question);
    if (selection.isEmpty) return Colors.grey; // not visited
    return selection.isNotEmpty ? Colors.green : Colors.yellow;
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkFast',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF2563EB),
      ),
      home: Scaffold(
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    style: GoogleFonts.poppins(color: const Color(0xFFE2E8F0), fontSize: 24, fontWeight: FontWeight.bold),
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
                        "Question: ${currentData["question"]?.toString() ?? ""}",
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  final String opt;
  final String type;
  final Map<String, Object> quizResultChunk;
  Color colour = Colors.black;

  buttons_opt(this.type, this.opt, this.onPressed, this.quizResultChunk, {super.key});

  List<String> _getSelection() {
    final sel = quizResultChunk["selection"];
    if (sel is List) {
      return sel.map((e) => e.toString()).toList();
    } else if (sel is String && sel.isNotEmpty) {
      return [sel];
    }
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final selectionList = _getSelection();
    final bool isSelected = selectionList.contains(opt);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: () {
          final sel = _getSelection();
          if (type == "Single Choice") {
            quizResultChunk["selection"] = [opt];
          } else {
            if (sel.contains(opt)) {
              sel.remove(opt);
            } else {
              sel.add(opt);
            }
            quizResultChunk["selection"] = sel;
          }
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          backgroundColor: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1E293B),
          foregroundColor: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          side: BorderSide(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            opt,
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

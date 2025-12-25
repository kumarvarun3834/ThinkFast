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
      title: 'Custom AppBar',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text("Quiz name"),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
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
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: switchToResultScreen,
                child: const Text(
                  "SUBMIT",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              color: Colors.redAccent,
              height: 30,
              alignment: Alignment.center,
              child: Text(
                _timer?.isActive == true
                    ? "⏳ Time left: ${_format(_timeLeft)}"
                    : "No active timer",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        drawer: Drawer(
          child: Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'Questions',
                  style: TextStyle(color: Colors.white, fontSize: 24),
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 36, 7, 156),
                Color.fromARGB(255, 8, 0, 255),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  width: double.infinity,
                  child: Card(
                    color: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Question: ${currentData["question"]?.toString() ?? ""}",
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(255, 0, 255, 255),
                          fontSize: 30,
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
              Container(
                margin: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: i > 0
                          ? () {
                        i--;
                        switchState();
                      }
                          : null,
                      child: TextContainer("PREVIOUS", Colors.black, 18),
                    ),
                    ElevatedButton(
                      onPressed: i < global.quizData.length - 1
                          ? () {
                        i++;
                        switchState();
                      }
                          : null,
                      child: TextContainer("NEXT", Colors.black, 18),
                    ),
                  ],
                ),
              ),
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
    colour =
    selectionList.contains(opt) ? Colors.lightGreenAccent : Colors.black;

    return Container(
      width: 350,
      child: OutlinedButton.icon(
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
          print(quizResultChunk);
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          backgroundColor: Colors.white10,
          foregroundColor: colour,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        label: TextContainer(opt, colour, 20),
        icon: const Icon(Icons.circle, size: 10, color: Colors.transparent),
      ),
    );
  }
}

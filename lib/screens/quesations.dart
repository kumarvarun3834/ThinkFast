import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

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
  bool _isSubmitted = false;

  /// 🔀 Shuffle questions & choices
  void _shuffleQuestionsAndOptions() {
    final random = Random();

    // 1. Group questions by Subject/Module
    Map<String, List<Map<String, dynamic>>> moduleGroups = {};
    for (var q in global.quizData) {
      final subject = q['subject']?.toString() ?? 'General';
      moduleGroups.putIfAbsent(subject, () => []).add(q);
    }

    // 2. Layer 1: Shuffle subjects
    List<String> subjectKeys = moduleGroups.keys.toList();
    subjectKeys.shuffle(random);

    List<Map<String, Object>> finalQuestions = [];

    // 3. Process each subject
    for (var subject in subjectKeys) {
      var moduleQuestions = moduleGroups[subject]!;

      // 4. Layer 2: Group by Type within subject to maintain specific order
      // Order: Single Choice -> Multiple Choice -> Integer
      Map<String, List<Map<String, dynamic>>> typeGroups = {
        'Single Choice': [],
        'Multiple Choice': [],
        'Integer': [],
      };

      for (var q in moduleQuestions) {
        final type = q['type']?.toString() ?? 'Single Choice';
        typeGroups.putIfAbsent(type, () => []).add(q);
      }

      // 5. Shuffle questions internally within each type group and assemble
      final List<String> typeOrder = [
        'Single Choice',
        'Multiple Choice',
        'Integer',
      ];

      // Also catch any other types not in our primary list
      final allTypes = typeGroups.keys.toList();
      for (var t in allTypes) {
        if (!typeOrder.contains(t)) typeOrder.add(t);
      }

      for (var type in typeOrder) {
        var group = typeGroups[type] ?? [];
        if (group.isEmpty) continue;

        group.shuffle(random); // Shuffle questions of this type
        finalQuestions.addAll(group.cast<Map<String, Object>>());
      }
    }

    global.quizData = finalQuestions;

    for (var q in global.quizData) {
      // Shuffle choices (As is [{id, text}, ...])
      final opts = (q["As"] as List?)?.toList() ?? [];
      opts.shuffle(random);
      q["As"] = opts;
    }

    // 2D Array format for Results (Application State): [ [qText, qUid, selectionList, visitedBool, reviewBool], ... ]
    global.quizResult = global.quizData.map((q) {
      final qInfo = q["Q"] as Map;
      final qUid = qInfo['id'].toString();
      final qText = qInfo['text'].toString();

      return [
        qText,
        qUid,
        <String>[], // Store selected optUids
        false, // visited
        false, // marked for review
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
        false, // marked for review
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
      if (global.quizResult.isNotEmpty) {
        global.quizResult[i][3] = true; // Mark first question as visited
      }
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

  void _showSubmitConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Submit Quiz?",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: global.quizData.length,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: _getQuestionColor(
                                global.quizResult[index],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                "${index + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Color(0xFF334155), height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildLegendItem(Colors.green, "Answered"),
                          _buildLegendItem(Colors.purple, "Marked for Review"),
                          _buildLegendItem(Colors.blue, "Seen"),
                          _buildLegendItem(Colors.grey, "Unseen"),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF334155),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "CANCEL",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                switchToResultScreen();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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
    final String type = quizData["type"]?.toString() ?? "Single Choice";

    if (type == "Integer") {
      final TextEditingController controller = TextEditingController();
      final List<String> currentSelection = _getSelection(global.quizResult[i]);
      if (currentSelection.isNotEmpty) {
        controller.text = currentSelection.first;
      }

      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            style: GoogleFonts.poppins(
              color: const Color(0xFFE2E8F0),
              fontSize: 20,
            ),
            decoration: InputDecoration(
              labelText: "Enter Integer Answer",
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
            onChanged: (val) {
              global.quizResult[i][2] = [val.trim()];
              switchState();
            },
          ),
        ),
      ];
    }

    List<Widget> database = [];

    // As is [{id, text}, ...]
    final List<dynamic> options = quizData["As"] as List? ?? [];

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
    final bool isVisited = (question.length > 3)
        ? (question[3] as bool)
        : false;
    final bool isMarkedForReview = (question.length > 4)
        ? (question[4] as bool)
        : false;

    if (isMarkedForReview) return Colors.purple; // Marked for Review
    if (selection.isNotEmpty) return Colors.green; // Answered
    if (isVisited) return Colors.blue; // Seen
    return Colors.grey; // Unseen
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
                onPressed: _showSubmitConfirmation,
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
                    ? "⏱ Time left: ${_format(_timeLeft)}"
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
          child: SingleChildScrollView(
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
                  child: Column(children: buttons_Data(currentData)),
                ),
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
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
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                global.quizResult[i][2] = <String>[];
                              });
                            },
                            child: const Text("CLEAR"),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: global.quizResult[i][4] == true
                                    ? Colors.purple
                                    : const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: global.quizResult[i][4] == true
                                      ? Colors.purple
                                      : const Color(0xFF334155),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  global.quizResult[i][4] =
                                      !(global.quizResult[i][4] as bool);
                                });
                              },
                              icon: Icon(
                                global.quizResult[i][4] == true
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 18,
                              ),
                              label: const Text("MARK FOR REVIEW"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.purpleAccent,
                                side: const BorderSide(color: Colors.purpleAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  global.quizResult[i][4] = true;
                                  if (i < global.quizData.length - 1) {
                                    i++;
                                    switchState();
                                  }
                                });
                              },
                              icon: const Icon(Icons.forward, size: 18),
                              label: const Text("REVIEW & NEXT"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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

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
  late final TextEditingController _integerController;

  /// 🔀 Shuffle questions & choices
  void _shuffleQuestionsAndOptions() {
    final random = Random();
    List<Map<String, Object>> shuffledQuestions = [];

    if (global.completeRandomShuffle) {
      // 1. Simply global shuffle across all modules
      shuffledQuestions = List<Map<String, Object>>.from(global.quizData);
      shuffledQuestions.shuffle(random);
    } else {
      // 2. Module-wise randomization
      // Group questions by subject
      Map<String, List<Map<String, Object>>> moduleGroups = {};
      for (var q in global.quizData) {
        String subject = q['subject']?.toString() ?? 'General';
        moduleGroups.putIfAbsent(subject, () => []).add(q);
      }

      // Shuffle which module appears first
      List<String> modules = moduleGroups.keys.toList();
      modules.shuffle(random);

      // Group by type within each module and shuffle within types
      final List<String> typeOrder = [
        'Single Choice',
        'Multiple Choice',
        'Integer'
      ];

      for (var module in modules) {
        List<Map<String, Object>> moduleQuestions = moduleGroups[module]!;

        // Group by type
        Map<String, List<Map<String, Object>>> typeGroups = {};
        for (var q in moduleQuestions) {
          String type = q['type']?.toString() ?? 'Single Choice';
          typeGroups.putIfAbsent(type, () => []).add(q);
        }

        // Add to shuffled list in specific type order
        for (var type in typeOrder) {
          if (typeGroups.containsKey(type)) {
            List<Map<String, Object>> questionsOfType = typeGroups[type]!;
            questionsOfType.shuffle(random);
            shuffledQuestions.addAll(questionsOfType);
          }
        }

        // Add any types not in the standard order list (if any)
        typeGroups.forEach((type, questions) {
          if (!typeOrder.contains(type)) {
            questions.shuffle(random);
            shuffledQuestions.addAll(questions);
          }
        });
      }
    }

    global.quizData = shuffledQuestions;

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
    _integerController = TextEditingController();
    // Hide status bar and navigation bar (Immersive Mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadQuizWithTime(); // fetch from Firestore
  }

  @override
  void dispose() {
    _integerController.dispose();
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
    int timeSeconds = global.time;
    
    // Check if first question has a custom timer
    final firstQ = global.quizData.isNotEmpty ? global.quizData[0] : null;
    final int qTimer = int.tryParse(firstQ?['timer']?.toString() ?? '0') ?? 0;
    
    if (qTimer > 0) {
      timeSeconds = qTimer;
    } else if (global.perQuestionTime > 0) {
      timeSeconds = global.perQuestionTime;
    }

    if (!global.isReviewMode) {
      _shuffleQuestionsAndOptions();
    }

    setState(() {
      currentData = global.quizData[i];
      _timeLeft = Duration(seconds: timeSeconds.toInt()); // ⏱️ assign from DB
      if (global.quizResult.isNotEmpty) {
        global.quizResult[i][3] = true; // Mark first question as visited
      }
    });

    if (!global.isReviewMode && global.time > 0) {
      _startTimer();
    }
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
      backgroundColor: global.cardColor,
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
                            decoration: _getQuestionDecoration(index),
                            child: Center(
                              child: Text(
                                _getDisplayNumber(index),
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
                    const Divider(color: global.borderColor, height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildLegendItem(Colors.green, "Answered"),
                          _buildLegendItem(global.reviewColor, "Marked for Review"),
                          _buildLegendItem(global.infoColor, "Seen"),
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
                                  color: global.borderColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "CANCEL",
                                style: TextStyle(color: global.valueColor),
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
                                backgroundColor: global.btnColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "SUBMIT",
                                style: TextStyle(
                                  color: global.valueColor,
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

      if (!global.isReviewMode) {
        final int qTimer = int.tryParse(currentData['timer']?.toString() ?? '0') ?? 0;
        if (qTimer > 0) {
          _timeLeft = Duration(seconds: qTimer);
          _startTimer();
        } else if (global.perQuestionTime > 0) {
          _timeLeft = Duration(seconds: global.perQuestionTime);
          _startTimer();
        }
      }

      // Sync integer controller if needed
      if (currentData["type"] == "Integer") {
        final List<String> sel = _getSelection(global.quizResult[i]);
        final String val = sel.isNotEmpty ? sel.first : "";
        if (_integerController.text != val) {
          _integerController.text = val;
        }
      }
    });
  }

  List<Widget> buttons_Data(Map<String, Object> quizData) {
    final String type = quizData["type"]?.toString() ?? "Single Choice";
    final String qUid = (quizData["Q"] as Map?)?['id']?.toString() ?? "";
    final bool limitReached = _isLimitReached();

    if (type == "Integer") {
      final String correctVal =
          global.correctAnswers[qUid]?.isNotEmpty == true
              ? global.correctAnswers[qUid]!.first
              : "";
      final String userVal = _integerController.text.trim();
      final bool isAnswered = userVal.isNotEmpty;
      final bool isCorrect = global.isReviewMode && isAnswered && userVal == correctVal;
      final bool isWrong = global.isReviewMode && isAnswered && userVal != correctVal;

      return [
        if (limitReached)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "⚠ Attempt limit reached for this section.",
              style: GoogleFonts.poppins(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: TextField(
            controller: _integerController,
            enabled: !global.isReviewMode && (!limitReached || isAnswered),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            style: GoogleFonts.poppins(
              color: global.isReviewMode
                  ? (isCorrect
                      ? global.successColor
                      : (isWrong ? global.errorColor : global.valueColor))
                  : (limitReached && !isAnswered ? global.hintColor : global.valueColor),
              fontSize: 20,
            ),
            decoration: InputDecoration(
              labelText: global.isReviewMode
                  ? (isAnswered ? "Integer Answer Review" : "Not Answered")
                  : (limitReached && !isAnswered ? "Limit Reached" : "Enter Integer Answer"),
              labelStyle: TextStyle(
                color: global.isReviewMode
                    ? (isCorrect
                        ? global.successColor
                        : (isWrong ? global.errorColor : global.labelColor))
                    : (limitReached && !isAnswered ? global.hintColor : global.labelColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: global.isReviewMode
                      ? (isCorrect
                          ? global.successColor
                          : (isWrong ? global.errorColor : global.borderColor))
                      : (limitReached && !isAnswered ? global.cardColor : global.borderColor),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: global.isReviewMode
                      ? (isCorrect
                          ? global.successColor
                          : (isWrong ? global.errorColor : global.borderColor))
                      : (limitReached && !isAnswered ? global.cardColor : global.borderColor),
                  width: (isCorrect || isWrong) ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: global.primaryAccent),
              ),
            ),
            onChanged: (val) {
              global.quizResult[i][2] = [val.trim()];
              global.quizResult[i][3] = true; // visited
              setState(() {}); // Refresh to update limit status across quiz
            },
          ),
        ),
        if (global.isReviewMode)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Correct Value: $correctVal",
                  style: GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ];
    }

    List<Widget> database = [];

    // As is [{id, text}, ...]
    final List<dynamic> options = quizData["As"] as List? ?? [];

    if (limitReached && _getSelection(global.quizResult[i]).isEmpty) {
      database.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "⚠ Attempt limit reached for this section.",
            style: GoogleFonts.poppins(color: global.warningColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    for (var option in options) {
      if (option is Map) {
        final String optUid = option['id'].toString();
        final String optText = option['text'].toString();

        database.add(
          buttons_opt(
            quizData["type"]?.toString() ?? "Single Choice",
            optUid,
            optText,
            () {
               switchState();
               setState(() {}); // Force update for limit check
            },
            global.quizResult[i],
            isLimitReached: limitReached,
          ),
        );
      }
    }
    return database;
  }

  List<Widget> menu_opt() {
    if (global.completeRandomShuffle) {
      return [
        for (int j = 0; j < global.quizData.length; j++)
          _buildQuestionCircle(j, (j + 1).toString()),
      ];
    }

    // Module-wise grouping in drawer
    List<Widget> groupedWidgets = [];
    String lastSubject = "";
    List<Widget> moduleCircles = [];
    int moduleQuestionCounter = 0;

    void flushModule() {
      if (moduleCircles.isNotEmpty) {
        groupedWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.from(moduleCircles),
            ),
          ),
        );
        moduleCircles.clear();
      }
    }

    for (int j = 0; j < global.quizData.length; j++) {
      String subject = global.quizData[j]['subject']?.toString() ?? 'General';

      if (subject != lastSubject) {
        flushModule();
        lastSubject = subject;
        moduleQuestionCounter = 0;
        groupedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded,
                    color: Color(0xFF3B82F6), size: 16),
                const SizedBox(width: 8),
                Text(
                  subject.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: global.primaryAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      moduleQuestionCounter++;
      moduleCircles
          .add(_buildQuestionCircle(j, moduleQuestionCounter.toString()));
    }
    flushModule();

    return groupedWidgets;
  }

  String _getDisplayNumber(int index) {
    if (global.completeRandomShuffle) return (index + 1).toString();
    int counter = 0;
    String currentSubject =
        global.quizData[index]['subject']?.toString() ?? 'General';
    for (int j = index; j >= 0; j--) {
      if ((global.quizData[j]['subject']?.toString() ?? 'General') ==
          currentSubject) {
        counter++;
      } else {
        break;
      }
    }
    return counter.toString();
  }

  Widget _buildQuestionCircle(int index, String displayNum) {
    return GestureDetector(
      onTap: (global.perQuestionTime > 0 && index < i && !global.isReviewMode)
          ? null
          : () {
              i = index;
              switchState();
              Navigator.pop(context); // Close the drawer
            },
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(4),
        decoration: _getQuestionDecoration(index, isCurrent: i == index),
        child: Center(
          child: Text(
            displayNum,
            style: TextStyle(
              color: (global.perQuestionTime > 0 && index < i && !global.isReviewMode) 
                  ? Colors.white.withOpacity(0.3) 
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ safe selector (2D Array)
  List<String> _getSelection(List<dynamic> question) {
    final sel = question[2];
    if (sel is List) {
      return sel.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  bool _isLimitReached() {
    if (global.isReviewMode) return false;
    final limits = global.attemptLimits;
    if (limits['type'] == 'none') return false;

    final String currentSubject = currentData['subject']?.toString() ?? 'General';
    final String currentType = currentData['type']?.toString() ?? 'Single Choice';

    int limit = -1;
    if (limits['type'] == 'global') {
      limit = limits['global']?[currentType] ?? -1;
    } else if (limits['type'] == 'per_module') {
      limit = limits['perModule']?[currentSubject]?[currentType] ?? -1;
    }

    if (limit == -1) return false;

    // Count how many questions of this type/module have answers
    int answeredCount = 0;
    for (int j = 0; j < global.quizData.length; j++) {
      final q = global.quizData[j];
      final r = global.quizResult[j];
      
      final String subject = q['subject']?.toString() ?? 'General';
      final String type = q['type']?.toString() ?? 'Single Choice';
      final selection = _getSelection(r);

      if (subject == currentSubject && type == currentType && selection.isNotEmpty) {
        // If it's the current question and it's already answered, don't count it towards the limit "block" 
        // logic if we want to allow changing answers.
        // But usually "N out of M" means once you pick N, you are done.
        answeredCount++;
      }
    }

    // If current question is NOT answered yet, and count is already >= limit, then BLOCKED.
    final currentSelection = _getSelection(global.quizResult[i]);
    if (currentSelection.isEmpty && answeredCount >= limit) {
      return true;
    }

    return false;
  }

  List<int> _getCurrentModuleIndices() {
    if (global.completeRandomShuffle || global.quizData.isEmpty) {
      return List.generate(global.quizData.length, (index) => index);
    }

    final String currentSubject =
        global.quizData[i]['subject']?.toString() ?? 'General';

    int start = i;
    while (start > 0 &&
        (global.quizData[start - 1]['subject']?.toString() ?? 'General') ==
            currentSubject) {
      start--;
    }

    int end = i;
    while (end < global.quizData.length - 1 &&
        (global.quizData[end + 1]['subject']?.toString() ?? 'General') ==
            currentSubject) {
      end++;
    }

    return List.generate(end - start + 1, (index) => start + index);
  }

  Widget _buildLimitStatusIndicator() {
    final limits = global.attemptLimits;
    final String currentSubject = currentData['subject']?.toString() ?? 'General';
    final String currentType = currentData['type']?.toString() ?? 'Single Choice';

    int limit = -1;
    if (limits['type'] == 'global') {
      limit = limits['global']?[currentType] ?? -1;
    } else if (limits['type'] == 'per_module') {
      limit = limits['perModule']?[currentSubject]?[currentType] ?? -1;
    }

    if (limit == -1) return const SizedBox.shrink();

    int answeredCount = 0;
    for (int j = 0; j < global.quizData.length; j++) {
      if ((global.quizData[j]['subject']?.toString() ?? 'General') == currentSubject &&
          (global.quizData[j]['type']?.toString() ?? 'Single Choice') == currentType &&
          _getSelection(global.quizResult[j]).isNotEmpty) {
        answeredCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (answeredCount >= limit ? global.warningColor : global.infoColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (answeredCount >= limit ? global.warningColor : global.infoColor).withOpacity(0.5)),
      ),
      child: Text(
        "Limit: $answeredCount/$limit",
        style: GoogleFonts.poppins(
          color: answeredCount >= limit ? global.warningColor : global.infoColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Decoration _getQuestionDecoration(int index, {bool isCurrent = false}) {
    final List<dynamic> question = global.quizResult[index];
    final selection = _getSelection(question);
    final bool isVisited = (question.length > 3) ? (question[3] as bool) : false;
    final bool isMarkedForReview = (question.length > 4) ? (question[4] as bool) : false;
    final bool isAnswered = selection.isNotEmpty;

    // Correctness logic for Review Mode
    bool isCorrect = false;
    bool isWrong = false;
    if (global.isReviewMode && isAnswered) {
      final String qUid = question[1].toString();
      final List<String> correct = global.correctAnswers[qUid] ?? [];
      final String? qType = global.quizData[index]['type']?.toString();

      if (qType == "Integer") {
        final String userVal = selection.first.trim();
        final String correctVal = correct.isNotEmpty ? correct.first.trim() : "";
        isCorrect = userVal == correctVal;
        isWrong = !isCorrect;
      } else {
        isCorrect = selection.length == correct.length &&
            selection.every((s) => correct.contains(s));
        isWrong = !isCorrect;
      }
    }

    if (isMarkedForReview) {
      List<Color> gradientColors = [global.reviewColor, Colors.grey];
      if (global.isReviewMode) {
        if (isCorrect) {
          gradientColors = [global.reviewColor, Colors.green];
        } else if (isWrong) {
          gradientColors = [global.reviewColor, global.errorColor];
        } else {
          gradientColors = [global.reviewColor, Colors.grey];
        }
      } else {
        if (isAnswered) {
          gradientColors = [global.reviewColor, Colors.green];
        } else {
          gradientColors = [global.reviewColor, global.infoColor];
        }
      }

      return BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: global.primaryAccent, width: 3)
            : null,
      );
    }

    Color color = Colors.grey;
    if (global.isReviewMode) {
      if (isCorrect) {
        color = Colors.green;
      } else if (isWrong) {
        color = global.errorColor;
      } else {
        color = Colors.grey; // Not answered
      }
    } else {
      if (isAnswered) {
        color = Colors.green;
      } else if (isVisited) {
        color = global.infoColor;
      } else {
        color = Colors.grey;
      }
    }

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: isCurrent
          ? Border.all(color: global.primaryAccent, width: 3)
          : null,
    );
  }

  Color _getQuestionColor(List<dynamic> question) {
    final selection = _getSelection(question);
    final bool isVisited = (question.length > 3)
        ? (question[3] as bool)
        : false;
    final bool isMarkedForReview = (question.length > 4)
        ? (question[4] as bool)
        : false;

    if (isMarkedForReview) return global.reviewColor; // Marked for Review
    if (selection.isNotEmpty) return Colors.green; // Answered
    if (isVisited) return global.infoColor; // Seen
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
          if (global.perQuestionTime > 0) {
            // Per Question Time Up
            if (i < global.quizData.length - 1) {
              i++;
              switchState();
            } else {
              t.cancel();
              switchToResultScreen();
            }
          } else {
            // Global Quiz Time Up
            t.cancel();
            switchToResultScreen();
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<int> moduleIndices = _getCurrentModuleIndices();

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
        backgroundColor: global.bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Quiz",
            style: GoogleFonts.poppins(color: global.valueColor),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: global.valueColor),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: global.isReviewMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: global.valueColor),
                      onPressed: () {
                        global.isReviewMode = false;
                        Navigator.pop(context);
                      },
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: global.btnColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showSubmitConfirmation,
                      child: const Text(
                        "SUBMIT",
                        style: TextStyle(
                          color: global.valueColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: Container(
              color: global.cardColor,
              height: 30,
              alignment: Alignment.center,
              child: Text(
                global.isReviewMode
                    ? "REVIEW MODE"
                    : (global.time == 0
                        ? "⏱ Unlimited Time"
                        : (_timer?.isActive == true
                            ? "⏱ ${global.perQuestionTime > 0 ? 'Q' : 'Time'} left: ${_format(_timeLeft)}"
                            : "No active timer")),
                style: TextStyle(
                  color: global.isReviewMode ? global.warningColor : global.valueColor,
                  fontSize: 14,
                  fontWeight: global.isReviewMode ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: global.cardColor,
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: global.bgColor),
                child: Center(
                  child: Text(
                    'Questions',
                    style: GoogleFonts.poppins(
                      color: global.valueColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: global.completeRandomShuffle
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: menu_opt(),
                        )
                      : Column(
                          children: menu_opt(),
                        ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        body: Container(
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // 🔝 Navigation & Status Block at Top
              Container(
                color: global.cardColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: moduleIndices.length,
                        itemBuilder: (context, index) {
                          int globalIndex = moduleIndices[index];
                          bool isCurrent = i == globalIndex;
                          bool isLocked = global.perQuestionTime > 0 && globalIndex < i && !global.isReviewMode;
                          
                          return GestureDetector(
                            onTap: isLocked
                                ? null
                                : () {
                                    i = globalIndex;
                                    switchState();
                                  },
                            child: Container(
                              width: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: _getQuestionDecoration(
                                globalIndex,
                                isCurrent: isCurrent,
                              ),
                              child: Center(
                                child: Text(
                                  _getDisplayNumber(globalIndex),
                                  style: TextStyle(
                                    color: isLocked ? global.valueColor.withOpacity(0.3) : global.valueColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: global.bgColor,
                                  foregroundColor: global.valueColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  side: BorderSide(
                                    color: global.borderColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed:
                                    (i > 0 && !(global.perQuestionTime > 0 && !global.isReviewMode))
                                        ? () {
                                          i--;
                                          switchState();
                                        }
                                        : null,
                                child: const Icon(Icons.arrow_back_ios, size: 14),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: global.btnColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed:
                                    i < global.quizData.length - 1
                                        ? () {
                                          i++;
                                          switchState();
                                        }
                                        : null,
                                child: Row(
                                  children: [
                                    const Text(
                                      "NEXT",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: global.bgColor,
                              foregroundColor: global.errorColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: const Size(0, 36),
                              side: BorderSide(color: global.errorColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                global.quizResult[i][2] = <String>[];
                                if (currentData["type"] == "Integer") {
                                  _integerController.clear();
                                }
                              });
                            },
                            child: const Text("CLEAR"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: global.primaryAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: global.primaryAccent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                (currentData["subject"]?.toString() ??
                                        "General")
                                    .toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: global.primaryAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: global.labelColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: global.labelColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                (currentData["type"]?.toString() ??
                                        "Single Choice")
                                    .toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: global.labelColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (!global.isReviewMode && global.attemptLimits['type'] != 'none')
                               _buildLimitStatusIndicator(),
                            Text(
                              "Question ${_getDisplayNumber(i)} of ${moduleIndices.length}",
                              style: GoogleFonts.poppins(
                                color: global.labelColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          width: double.infinity,
                          child: Card(
                            color: global.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: global.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                "${(currentData["Q"] as Map?)?['text'] ?? ""}",
                                style: GoogleFonts.poppins(
                                  color: global.valueColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        width: double.infinity,
                        child: Column(children: buttons_Data(currentData)),
                      ),
                      if (global.isReviewMode && global.solutions.containsKey(currentData['uid']?.toString() ?? ""))
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: global.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: global.primaryAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: global.primaryAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "SOLUTION",
                                    style: GoogleFonts.poppins(
                                      color: global.primaryAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                global.solutions[currentData['uid']?.toString()] ?? "",
                                style: GoogleFonts.poppins(
                                  color: global.valueColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 30),
                      Container(
                        margin: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  backgroundColor:
                                      global.quizResult[i][4] == true
                                          ? global.reviewColor
                                          : global.cardColor,
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: global.quizResult[i][4] == true
                                        ? global.reviewColor
                                        : global.borderColor,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  backgroundColor: global.cardColor,
                                  foregroundColor: global.warningColor,
                                  side: const BorderSide(
                                    color: global.warningColor,
                                  ),
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
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
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
  final String optUid;
  final String optText;
  final String type;
  final List<dynamic> quizResultChunk;
  final bool isLimitReached;

  buttons_opt(
    this.type,
    this.optUid,
    this.optText,
    this.onPressed,
    this.quizResultChunk, {
    this.isLimitReached = false,
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
    final String qUid = quizResultChunk[1].toString();
    final bool isCorrect = global.correctAnswers[qUid]?.contains(optUid) ?? false;
    final bool isBlocked = isLimitReached && !isSelected;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: (global.isReviewMode || isBlocked)
            ? null
            : () {
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
          backgroundColor: global.isReviewMode
              ? (isCorrect
                  ? Colors.green.withOpacity(0.15)
                  : (isSelected ? global.errorColor.withOpacity(0.1) : global.cardColor))
              : (isSelected
                  ? global.primaryAccent.withOpacity(0.2)
                  : (isBlocked ? global.bgColor.withOpacity(0.5) : global.cardColor)),
          foregroundColor: global.isReviewMode
              ? (isCorrect
                  ? Colors.greenAccent
                  : (isSelected ? global.errorColor : global.valueColor))
              : (isSelected ? global.primaryAccent : (isBlocked ? global.hintColor : global.valueColor)),
          side: BorderSide(
            color: global.isReviewMode
                ? (isCorrect
                    ? Colors.greenAccent
                    : (isSelected ? global.errorColor : global.borderColor))
                : (isSelected ? global.primaryAccent : (isBlocked ? global.bgColor : global.borderColor)),
            width: (global.isReviewMode && (isCorrect || isSelected)) || (!global.isReviewMode && isSelected) ? 2.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      optText,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: (isCorrect || isSelected) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (global.isReviewMode) ...[
                      if (isCorrect && isSelected)
                        const Text("Correct choice",
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))
                      else if (isCorrect)
                        const Text("Correct answer",
                            style: TextStyle(
                                color: Colors.greenAccent, fontSize: 10))
                      else if (isSelected)
                        Text("Your incorrect choice",
                            style: TextStyle(
                                color: global.errorColor, fontSize: 10)),
                    ]
                  ],
                ),
              ),
              if (global.isReviewMode) ...[
                if (isCorrect)
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 20)
                else if (isSelected)
                  Icon(Icons.cancel, color: global.errorColor, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

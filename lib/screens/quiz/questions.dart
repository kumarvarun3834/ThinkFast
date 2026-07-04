import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class Questions extends StatefulWidget {
  const Questions({super.key});

  @override
  State<Questions> createState() => _QuestionsState();
}

class _QuestionsState extends State<Questions> with WidgetsBindingObserver {
  int i = 0;
  String? _activeModule;
  String? _drawerActiveModule;
  bool _isDefaultOrder = false; // Start with History/Attempt order (false)
  Map<String, Object> currentData = {};
  Duration _timeLeft = Duration.zero; // ⏱️ dynamic time from Firestore
  Timer? _timer;
  bool _isSubmitted = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  String _loadingMessage = "Initializing Quiz...";
  late final TextEditingController _integerController;
  int _backPressCount = 0;

  // List of indices in global.quizData in the order we want to display them
  List<int> _displaySequence = [];

  void _updateDisplaySequence() {
    List<int> indices = List.generate(global.quizData.length, (index) => index);

    if (global.isReviewMode && _isDefaultOrder) {
      // "Quiz Actual Format" - Sort by original question order if available
      if (global.originalQuestionOrder.isNotEmpty) {
        indices.sort((a, b) {
          final idA = (global.quizData[a]['Q'] as Map)['id'].toString();
          final idB = (global.quizData[b]['Q'] as Map)['id'].toString();
          final posA = global.originalQuestionOrder.indexOf(idA);
          final posB = global.originalQuestionOrder.indexOf(idB);

          if (posA != -1 && posB != -1) return posA.compareTo(posB);
          return idA.compareTo(idB); // Fallback to ID
        });
      } else {
        // Fallback: sort by subject then ID
        indices.sort((a, b) {
          String subA = global.quizData[a]['subject']?.toString() ?? 'General';
          String subB = global.quizData[b]['subject']?.toString() ?? 'General';
          if (subA != subB) return subA.compareTo(subB);
          return (global.quizData[a]['Q'] as Map)['id'].toString().compareTo(
            (global.quizData[b]['Q'] as Map)['id'].toString(),
          );
        });
      }
    }
    // Else: "User Shuffled Persistent" - use indices as they are (shuffled at start)

    setState(() {
      _displaySequence = indices;
    });
  }

  /// 🔀 Shuffle questions & choices
  void _shuffleQuestionsAndOptions() {
    final random = Random();
    List<Map<String, Object>> shuffledQuestions = [];

    if (global.completeRandomShuffle) {
      shuffledQuestions = List<Map<String, Object>>.from(global.quizData);
      shuffledQuestions.shuffle(random);
    } else {
      Map<String, List<Map<String, Object>>> moduleGroups = {};
      for (var q in global.quizData) {
        String subject = q['subject']?.toString() ?? 'General';
        moduleGroups.putIfAbsent(subject, () => []).add(q);
      }

      List<String> modules = moduleGroups.keys.toList();
      if (global.shuffleModules) {
        modules.shuffle(random);
      }

      final List<String> typeOrder = [
        'Single Choice',
        'Multiple Choice',
        'Integer',
      ];

      for (var module in modules) {
        List<Map<String, Object>> moduleQuestions = moduleGroups[module]!;

        if (global.shuffleQuestionsWithinModules) {
          Map<String, List<Map<String, Object>>> typeGroups = {};
          for (var q in moduleQuestions) {
            String type = q['type']?.toString() ?? 'Single Choice';
            typeGroups.putIfAbsent(type, () => []).add(q);
          }

          for (var type in typeOrder) {
            if (typeGroups.containsKey(type)) {
              List<Map<String, Object>> questionsOfType = typeGroups[type]!;
              questionsOfType.shuffle(random);
              shuffledQuestions.addAll(questionsOfType);
            }
          }

          typeGroups.forEach((type, questions) {
            if (!typeOrder.contains(type)) {
              questions.shuffle(random);
              shuffledQuestions.addAll(questions);
            }
          });
        } else {
          shuffledQuestions.addAll(moduleQuestions);
        }
      }
    }

    global.quizData = shuffledQuestions;

    for (var q in global.quizData) {
      final opts = (q["As"] as List?)?.toList() ?? [];
      opts.shuffle(random);
      q["As"] = opts;
    }

    global.quizResult = global.quizData.map((q) {
      final qInfo = q["Q"] as Map;
      final qUid = qInfo['id'].toString();
      final qText = qInfo['text'].toString();

      return [
        qText,
        qUid,
        <String>[], // selections
        false, // visited
        false, // marked review
      ];
    }).toList();
  }

  Map<String, int> _getMarkingConfig(String? type, String qUid) {
    final scheme = global.markingScheme;
    final schemeType = scheme['type'] ?? 'default';
    if (schemeType == 'entire_quiz') {
      return {
        'correct': (scheme['global']?['correct'] ?? 4).toInt(),
        'wrong': (scheme['global']?['wrong'] ?? -1).toInt(),
      };
    } else if (schemeType == 'per_question_type') {
      final pqt = scheme['perQuestionType'] as Map? ?? {};
      final config =
          pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
      return {
        'correct': (config['correct'] ?? 4).toInt(),
        'wrong': (config['wrong'] ?? -1).toInt(),
      };
    } else if (schemeType == 'per_question') {
      final pq = scheme['perQuestion'] as Map? ?? {};
      final config = pq[qUid] ?? {'correct': 4, 'wrong': -1};
      return {
        'correct': (config['correct'] ?? 4).toInt(),
        'wrong': (config['wrong'] ?? -1).toInt(),
      };
    }
    return {'correct': 4, 'wrong': -1};
  }

  int _getMarksForQuestion(int index) {
    final question = global.quizResult[index];
    final String qUid = question[1].toString();
    final List<String> selection = _getSelection(question);
    final String? qType = global.quizData[index]['type']?.toString();
    final List<String> correct = global.correctAnswers[qUid] ?? [];

    if (selection.isEmpty) return 0;

    // For Integer questions, treat empty string as unattempted
    if (qType == "Integer" && selection.first.toString().trim().isEmpty) {
      return 0;
    }

    final marking = _getMarkingConfig(qType, qUid);

    bool isCorrect = false;
    if (qType == "Integer") {
      final String userVal = selection.first.toString().trim();
      final String correctVal = correct.isNotEmpty ? correct.first.trim() : "";
      isCorrect = userVal == correctVal;
    } else {
      isCorrect =
          selection.length == correct.length &&
          selection.every((s) => correct.contains(s));
    }
    return isCorrect ? marking['correct']! : marking['wrong']!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _integerController = TextEditingController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadQuizWithTime();
  }

  @override
  void dispose() {
    _integerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        !_isSubmitted &&
        !global.isReviewMode &&
        global.time > 0) {
      _submitAndFinish();
    }
  }

  Future<void> _loadQuizWithTime() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
      _loadingMessage = global.isReviewMode
          ? "Loading Attempt Details..."
          : "Checking Environment...";
    });

    try {
      if (!global.isReviewMode) {
        // Artificial delay for "Checking Environment" as requested
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      if (global.quizData.isEmpty) {
        throw "Quiz data is empty. Please try reloading the quiz.";
      }

      if (!global.isReviewMode) {
        setState(() {
          _loadingMessage = "Shuffling Questions...";
        });
      }

      int timeSeconds = global.time;
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

      if (mounted) {
        setState(() {
          _updateDisplaySequence();
          if (global.isReviewMode &&
              global.reviewInitialIndex < _displaySequence.length) {
            i = _displaySequence[global.reviewInitialIndex];
          } else {
            i = _displaySequence.isNotEmpty ? _displaySequence[0] : 0;
          }
          currentData = global.quizData[i];
          _activeModule = currentData['subject']?.toString() ?? 'General';
          _timeLeft = Duration(seconds: timeSeconds.toInt());
          if (!global.isReviewMode && global.quizResult.isNotEmpty) {
            global.quizResult[i][3] = true; // Mark first question visited
          }
          _isLoading = false;
        });
      }

      if (!global.isReviewMode && global.time > 0) {
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _submitAndFinish() async {
    if (_isSubmitted) return;
    _isSubmitted = true;
    setState(() => _timer?.cancel());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/Quiz Result");
    }
  }

  void switchToResultScreen() {
    _submitAndFinish();
  }

  void _showSubmitConfirmation() {
    String? localActiveModule = _activeModule;
    final List<String> modules = _getModules();

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
            final List<int> moduleIndices = (global.completeRandomShuffle)
                ? List.generate(global.quizData.length, (index) => index)
                : global.quizData
                      .asMap()
                      .entries
                      .where(
                        (e) =>
                            (e.value['subject']?.toString() ?? 'General') ==
                            localActiveModule,
                      )
                      .map((e) => e.key)
                      .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            global.isReviewMode
                                ? "Review Navigator"
                                : "Submit Quiz?",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    if (global.isReviewMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSmallStat(
                              "Score",
                              "${_calculateCurrentTotalScore()}",
                              global.primaryAccent,
                            ),
                            _buildSmallStat(
                              "Answered",
                              "${_calculateAnsweredCount()}",
                              Colors.green,
                            ),
                            _buildSmallStat(
                              "Review",
                              "${_calculateReviewCount()}",
                              global.reviewColor,
                            ),
                          ],
                        ),
                      ),
                    if (!global.completeRandomShuffle && modules.length > 1)
                      Container(
                        height: 50,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: modules.length,
                          itemBuilder: (context, index) {
                            final m = modules[index];
                            final bool isSelected = localActiveModule == m;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  m.toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                selected: isSelected,
                                selectedColor: global.primaryAccent,
                                onSelected: (selected) {
                                  if (selected) {
                                    if (global
                                            .disableModuleSwitchingUntilTimeout &&
                                        _timeLeft.inSeconds > 0 &&
                                        !global.isReviewMode) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Module switching disabled until timeout",
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setModalState(() {
                                      localActiveModule = m;
                                    });
                                  }
                                },
                              ),
                            );
                          },
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
                        itemCount: moduleIndices.length,
                        itemBuilder: (context, index) {
                          int globalIndex = moduleIndices[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              setState(() {
                                i = globalIndex;
                                _activeModule = localActiveModule;
                                switchState();
                              });
                            },
                            child: Container(
                              decoration: _getQuestionDecoration(globalIndex),
                              child: Center(
                                child: Text(
                                  _getDisplayNumber(globalIndex),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem(Colors.green, "Answered"),
                              _buildLegendItem(
                                global.reviewColor,
                                "Marked for Review",
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLegendItem(Colors.grey, "Unattempted"),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (global.forceWaitUntilTimeout &&
                                    _timeLeft.inSeconds > 0 &&
                                    !global.isReviewMode) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Submission not allowed until time runs out",
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                if (global.isReviewMode) {
                                  Navigator.pop(context);
                                } else {
                                  switchToResultScreen();
                                }
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
                              child: Text(
                                global.isReviewMode
                                    ? "BACK TO SUMMARY"
                                    : "SUBMIT QUIZ",
                                style: const TextStyle(
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
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void switchState() {
    setState(() {
      _backPressCount = 0; // Reset back count on navigation
      currentData = global.quizData[i];
      _activeModule = currentData['subject']?.toString() ?? 'General';
      final qInfo = currentData["Q"] as Map;
      global.quizResult[i][0] = qInfo['text'].toString();
      global.quizResult[i][1] = qInfo['id'].toString();

      if (!global.isReviewMode && global.time > 0) {
        global.quizResult[i][3] = true; // Mark visited while attempting
        final int qTimer =
            int.tryParse(currentData['timer']?.toString() ?? '0') ?? 0;
        if (qTimer > 0) {
          _timeLeft = Duration(seconds: qTimer);
          _startTimer();
        } else if (global.perQuestionTime > 0) {
          _timeLeft = Duration(seconds: global.perQuestionTime);
          _startTimer();
        }
      }

      if (currentData["type"] == "Integer") {
        final List<String> sel = _getSelection(global.quizResult[i]);
        _integerController.text = sel.isNotEmpty ? sel.first : "";
      }
    });
  }

  List<Widget> buttonsData(int index) {
    final Map<String, Object> quizData = global.quizData[index];
    final String type = quizData["type"]?.toString() ?? "Single Choice";
    final String qUid = (quizData["Q"] as Map?)?['id']?.toString() ?? "";
    final bool limitReached = _isLimitReachedAtIndex(index);

    if (type == "Integer") {
      final String correctVal = global.correctAnswers[qUid]?.isNotEmpty == true
          ? global.correctAnswers[qUid]!.first
          : "";
      final List<String> sel = _getSelection(global.quizResult[index]);
      final String currentVal = sel.isNotEmpty ? sel.first : "";
      final bool isAnswered = currentVal.isNotEmpty;
      final bool isCorrect =
          global.isReviewMode && isAnswered && currentVal == correctVal;
      final bool isWrong =
          global.isReviewMode && isAnswered && currentVal != correctVal;

      return [
        if (limitReached && !isAnswered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "⚠ Attempt limit reached for this section.",
              style: GoogleFonts.poppins(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: TextField(
            onChanged: (val) {
              global.quizResult[index][2] = [val.trim()];
              global.quizResult[index][3] = true;
              setState(() {});
            },
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
                  : (limitReached && !isAnswered
                        ? global.hintColor
                        : global.valueColor),
              fontSize: 20,
            ),
            decoration: InputDecoration(
              labelText: global.isReviewMode
                  ? (isAnswered ? "Integer Answer Review" : "Not Answered")
                  : (limitReached && !isAnswered
                        ? "Limit Reached"
                        : "Enter Integer Answer"),
              labelStyle: TextStyle(
                color: global.isReviewMode
                    ? (isCorrect
                          ? global.successColor
                          : (isWrong ? global.errorColor : global.labelColor))
                    : (limitReached && !isAnswered
                          ? global.hintColor
                          : global.labelColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: global.isReviewMode
                      ? (isCorrect
                            ? global.successColor
                            : (isWrong
                                  ? global.errorColor
                                  : global.borderColor))
                      : (limitReached && !isAnswered
                            ? global.cardColor
                            : global.borderColor),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: global.isReviewMode
                      ? (isCorrect
                            ? global.successColor
                            : (isWrong
                                  ? global.errorColor
                                  : global.borderColor))
                      : (limitReached && !isAnswered
                            ? global.cardColor
                            : global.borderColor),
                  width: (isCorrect || isWrong) ? 2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: global.primaryAccent),
              ),
            ),
          ),
        ),
        if (global.isReviewMode)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 20,
                ),
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

    final List<dynamic> options = quizData["As"] as List? ?? [];
    List<Widget> database = [];

    if (limitReached && _getSelection(global.quizResult[index]).isEmpty) {
      database.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "⚠ Attempt limit reached for this section.",
            style: GoogleFonts.poppins(
              color: global.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    for (var option in options) {
      if (option is Map) {
        final String optUid = option['id'].toString();
        final String optText = option['text'].toString();

        database.add(
          ButtonsOpt(
            quizData["type"]?.toString() ?? "Single Choice",
            optUid,
            optText,
            () {
              setState(() {
                global.quizResult[index][3] = true;
              });
            },
            global.quizResult[index],
            isLimitReached: limitReached,
          ),
        );
      }
    }
    return database;
  }

  List<String> _getSelection(List<dynamic> question) {
    final sel = question[2];
    if (sel is List) return sel.map((e) => e.toString()).toList();
    return <String>[];
  }

  bool _isLimitReachedAtIndex(int index) {
    if (global.isReviewMode) return false;
    final limits = global.attemptLimits;
    if (limits['type'] == 'none') return false;

    final q = global.quizData[index];
    final String currentSubject = q['subject']?.toString() ?? 'General';
    final String currentType = q['type']?.toString() ?? 'Single Choice';

    int limit = -1;
    if (limits['type'] == 'global') {
      limit = limits['global']?[currentType] ?? -1;
    } else if (limits['type'] == 'per_module') {
      limit = limits['perModule']?[currentSubject]?[currentType] ?? -1;
    }

    if (limit == -1) return false;

    int answeredCount = 0;
    for (int j = 0; j < global.quizData.length; j++) {
      final subject = global.quizData[j]['subject']?.toString() ?? 'General';
      final type = global.quizData[j]['type']?.toString() ?? 'Single Choice';
      if (subject == currentSubject &&
          type == currentType &&
          _getSelection(global.quizResult[j]).isNotEmpty) {
        answeredCount++;
      }
    }

    final currentSelection = _getSelection(global.quizResult[index]);
    if (currentSelection.isEmpty && answeredCount >= limit) {
      return true;
    }
    return false;
  }

  List<String> _getModules() {
    List<String> modules = [];
    for (var q in global.quizData) {
      String subject = q['subject']?.toString() ?? 'General';
      if (!modules.contains(subject)) {
        modules.add(subject);
      }
    }
    return modules;
  }

  Widget _buildLimitStatusIndicatorAtIndex(int index) {
    final limits = global.attemptLimits;
    final q = global.quizData[index];
    final String currentSubject = q['subject']?.toString() ?? 'General';
    final String currentType = q['type']?.toString() ?? 'Single Choice';

    int limit = -1;
    if (limits['type'] == 'global') {
      limit = limits['global']?[currentType] ?? -1;
    } else if (limits['type'] == 'per_module') {
      limit = limits['perModule']?[currentSubject]?[currentType] ?? -1;
    }

    if (limit == -1) return const SizedBox.shrink();

    int answeredCount = 0;
    for (int j = 0; j < global.quizData.length; j++) {
      if ((global.quizData[j]['subject']?.toString() ?? 'General') ==
              currentSubject &&
          (global.quizData[j]['type']?.toString() ?? 'Single Choice') ==
              currentType &&
          _getSelection(global.quizResult[j]).isNotEmpty) {
        answeredCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (answeredCount >= limit ? global.warningColor : global.infoColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (answeredCount >= limit ? global.warningColor : global.infoColor)
                  .withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        "Limit: $answeredCount/$limit",
        style: GoogleFonts.poppins(
          color: answeredCount >= limit
              ? global.warningColor
              : global.infoColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Decoration _getQuestionDecoration(int index, {bool isCurrent = false}) {
    final List<dynamic> question = global.quizResult[index];
    final selection = _getSelection(question);
    final bool isVisited = (question.length > 3)
        ? (question[3] as bool)
        : false;
    final bool isMarkedForReview = (question.length > 4)
        ? (question[4] as bool)
        : false;
    final bool isAnswered = selection.isNotEmpty;

    bool isCorrect = false;
    bool isWrong = false;
    if (global.isReviewMode && isAnswered) {
      final marks = _getMarksForQuestion(index);
      isCorrect = marks > 0;
      isWrong = marks < 0;
    }

    if (isMarkedForReview) {
      List<Color> gradientColors = [global.reviewColor, Colors.grey];
      if (global.isReviewMode) {
        if (isCorrect) {
          gradientColors = [global.reviewColor, Colors.green];
        } else if (isWrong) {
          gradientColors = [global.reviewColor, global.errorColor];
        } else if (isVisited) {
          gradientColors = [global.reviewColor, global.infoColor];
        }
      } else {
        if (isAnswered) {
          gradientColors = [global.reviewColor, Colors.green];
        } else if (isVisited) {
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
      // In Review Mode, if not marked for review, keep dots looking like the quiz
      if (isAnswered) {
        color = Colors.green;
      } else if (isVisited) {
        color = global.infoColor;
      }
    } else {
      if (isAnswered) {
        color = Colors.green;
      } else if (isVisited) {
        color = global.infoColor;
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

  Color _getQuestionColor(int index) {
    final question = global.quizResult[index];
    final selection = _getSelection(question);
    final bool isMarkedForReview = (question.length > 4)
        ? (question[4] as bool)
        : false;

    if (global.isReviewMode) {
      if (selection.isEmpty) {
        // Skipped or Unseen - stay static (no tint) unless marked for review
        if (isMarkedForReview) return global.reviewColor;
        return Colors.transparent;
      }
      final marks = _getMarksForQuestion(index);
      return marks > 0 ? global.successColor : global.errorColor;
    }
    if (isMarkedForReview) return global.reviewColor;
    if (selection.isNotEmpty) return Colors.green;
    return (question.length > 3 && question[3] == true)
        ? global.infoColor
        : Colors.grey;
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
            if (i < global.quizData.length - 1) {
              i++;
              switchState();
            } else {
              t.cancel();
              switchToResultScreen();
            }
          } else {
            t.cancel();
            switchToResultScreen();
          }
        }
      });
    });
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

  int _calculateCurrentTotalScore() {
    int total = 0;
    for (int j = 0; j < global.quizData.length; j++) {
      total += _getMarksForQuestion(j);
    }
    return total;
  }

  int _calculateAnsweredCount() {
    int count = 0;
    for (int j = 0; j < global.quizResult.length; j++) {
      final result = global.quizResult[j];
      final List<String> selection = _getSelection(result);
      if (selection.isEmpty) continue;

      final String? qType = global.quizData[j]['type']?.toString();
      if (qType == "Integer" && selection.first.toString().trim().isEmpty) {
        continue;
      }
      count++;
    }
    return count;
  }

  int _calculateReviewCount() {
    int count = 0;
    for (var result in global.quizResult) {
      if (result.length > 4 && result[4] == true) count++;
    }
    return count;
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 10),
        ),
      ],
    );
  }

  void _showReportDialog(int index) {
    final Map<String, Object> question = global.quizData[index];
    final String qUid =
        (question["Q"] as Map?)?['id']?.toString() ??
        question['uid']?.toString() ??
        '';

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    String selectedReason = "Inaccurate Information";
    final List<String> reasons = [
      "Inaccurate Information",
      "Offensive Content",
      "Inappropriate Language",
      "Copyright Violation",
      "Spam",
      "Other",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: global.cardColor,
          title: Text(
            "Report Question",
            style: GoogleFonts.poppins(
              color: global.valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Why are you reporting this question?",
                  style: GoogleFonts.poppins(
                    color: global.labelColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: global.bgColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: global.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedReason,
                      dropdownColor: global.cardColor,
                      style: GoogleFonts.poppins(color: global.valueColor),
                      items: reasons
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedReason = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Provide more details (optional)...",
                    hintStyle: TextStyle(
                      color: global.labelColor,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: global.bgColor.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: global.errorColor,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final String userId =
                      global.currentUserProfile?['uid'] ??
                      FirebaseAuth.instance.currentUser?.uid ??
                      'anonymous';

                  await global.db.reportContent(
                    reporterId: userId,
                    targetType: 'question',
                    quizId: global.id,
                    questionId: qUid,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Thank you. Your report has been submitted.",
                      ),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text(
                "SUBMIT REPORT",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: global.bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: global.primaryAccent),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: GoogleFonts.poppins(
                  color: global.valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please do not close the app",
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: global.bgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: global.errorColor,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: global.valueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _loadQuizWithTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.btnColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    "RETRY LOADING",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("GO BACK"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<String> modules = _getModules();
    if (global.quizData.isEmpty || i >= global.quizData.length) {
      return const Scaffold(body: Center(child: Text("Invalid Quiz State")));
    }
    final Map<String, Object> question = global.quizData[i];
    final bool isLast = i == global.quizData.length - 1;
    final bool isFirst = i == 0;

    // Filter Q dots based on module
    final List<int> moduleIndices = (global.completeRandomShuffle)
        ? List.generate(global.quizData.length, (index) => index)
        : global.quizData
              .asMap()
              .entries
              .where(
                (e) =>
                    (e.value['subject']?.toString() ?? 'General') ==
                    _activeModule,
              )
              .map((e) => e.key)
              .toList();

    return PopScope(
      canPop: global.isReviewMode,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Allow immediate exit and state save (submit) for "any other location"
        // defined here as Unlimited Time sessions or Admin previews.
        if (global.time == 0 || global.isAdmin) {
          _submitAndFinish();
          return;
        }

        if (_backPressCount == 0) {
          _backPressCount++;
          _showSubmitConfirmation();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Warning: Attempting to exit. Press BACK again will submit.",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          _submitAndFinish();
        }
      },
      child: Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Quiz Session",
            style: GoogleFonts.poppins(
              color: global.valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: global.valueColor),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            if (global.isReviewMode && !global.completeRandomShuffle)
              IconButton(
                tooltip: _isDefaultOrder
                    ? "Switch to Attempt Order"
                    : "Switch to Default Format",
                icon: Icon(
                  _isDefaultOrder ? Icons.sort_rounded : Icons.history_rounded,
                  color: global.valueColor,
                ),
                onPressed: () {
                  setState(() {
                    _isDefaultOrder = !_isDefaultOrder;
                    _updateDisplaySequence();
                  });
                },
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: global.isReviewMode
                  ? Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.analytics_outlined,
                            color: global.valueColor,
                          ),
                          label: const Text(
                            "SUMMARY",
                            style: TextStyle(
                              color: global.valueColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: global.valueColor,
                          ),
                          onPressed: () {
                            global.isReviewMode = false;
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: global.btnColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        if (global.forceWaitUntilTimeout &&
                            _timeLeft.inSeconds > 0 &&
                            !global.isReviewMode) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Submission not allowed until time runs out",
                              ),
                            ),
                          );
                          return;
                        }
                        _showSubmitConfirmation();
                      },
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
          bottom: (global.time == 0 && !global.isReviewMode)
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(40),
                  child: Container(
                    color: global.cardColor,
                    height: 40,
                    alignment: Alignment.center,
                    child: Text(
                      global.isReviewMode
                          ? "REVIEW MODE"
                          : (_timer?.isActive == true
                                ? "⏱ ${global.perQuestionTime > 0 ? 'Q' : 'Time'} left: ${_format(_timeLeft)}"
                                : "No active timer"),
                      style: TextStyle(
                        color: global.isReviewMode
                            ? global.warningColor
                            : global.valueColor,
                        fontSize: 14,
                        fontWeight: global.isReviewMode
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
        ),
        drawer: Drawer(
          backgroundColor: global.cardColor,
          child: StatefulBuilder(
            builder: (context, setDrawerState) {
              _drawerActiveModule ??= (global.isReviewMode
                  ? "All"
                  : _activeModule);
              final List<String> drawerModules = ["All", ...modules];

              List<int> drawerModuleIndices = [];
              if (_drawerActiveModule == "All" ||
                  global.completeRandomShuffle) {
                drawerModuleIndices = global.isReviewMode
                    ? _displaySequence
                    : List.generate(global.quizData.length, (index) => index);
              } else {
                final sourceIndices = global.isReviewMode
                    ? _displaySequence
                    : List.generate(global.quizData.length, (index) => index);
                drawerModuleIndices = sourceIndices
                    .where(
                      (idx) =>
                          (global.quizData[idx]['subject']?.toString() ??
                              'General') ==
                          _drawerActiveModule,
                    )
                    .toList();
              }

              return Column(
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: global.bgColor),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Navigate',
                        style: GoogleFonts.poppins(
                          color: global.valueColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!global.completeRandomShuffle && modules.length > 1)
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: drawerModules.length,
                        itemBuilder: (context, index) {
                          final m = drawerModules[index];
                          final bool isSelected = _drawerActiveModule == m;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                m.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              selected: isSelected,
                              selectedColor: global.primaryAccent,
                              onSelected: (selected) {
                                if (selected) {
                                  if (global
                                          .disableModuleSwitchingUntilTimeout &&
                                      _timeLeft.inSeconds > 0 &&
                                      !global.isReviewMode) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Module switching disabled until timeout",
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setDrawerState(() {
                                    _drawerActiveModule = m;
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: drawerModuleIndices.length,
                      itemBuilder: (context, index) {
                        int globalIndex = drawerModuleIndices[index];
                        return GestureDetector(
                          onTap:
                              (global.perQuestionTime > 0 &&
                                  globalIndex < i &&
                                  !global.isReviewMode)
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _activeModule = global
                                        .quizData[globalIndex]['subject']
                                        ?.toString();
                                    i = globalIndex;
                                    switchState();
                                  });
                                },
                          child: Container(
                            decoration: _getQuestionDecoration(
                              globalIndex,
                              isCurrent: i == globalIndex,
                            ),
                            child: Center(
                              child: Text(
                                _getDisplayNumber(globalIndex),
                                style: TextStyle(
                                  color:
                                      (global.perQuestionTime > 0 &&
                                          globalIndex < i &&
                                          !global.isReviewMode)
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: global.borderColor),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildLegendItem(Colors.green, "Answered"),
                        _buildLegendItem(
                          global.reviewColor,
                          "Marked for Review",
                        ),
                        _buildLegendItem(Colors.grey, "Unattempted"),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              );
            },
          ),
        ),
        body: Column(
          children: [
            // Module Selector
            if (!global.completeRandomShuffle && modules.length > 1)
              Container(
                height: 50,
                margin: const EdgeInsets.only(top: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: global.isReviewMode
                      ? modules.length + 1
                      : modules.length,
                  itemBuilder: (context, index) {
                    if (global.isReviewMode && index == 0) {
                      final bool isSelected = _activeModule == "All";
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text(
                            "ALL",
                            style: TextStyle(fontSize: 10),
                          ),
                          selected: isSelected,
                          selectedColor: global.primaryAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _activeModule = "All";
                              });
                            }
                          },
                        ),
                      );
                    }

                    final m = global.isReviewMode
                        ? modules[index - 1]
                        : modules[index];
                    final bool isSelected = _activeModule == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          m.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: isSelected,
                        selectedColor: global.primaryAccent,
                        onSelected: (selected) {
                          if (selected) {
                            if (global.disableModuleSwitchingUntilTimeout &&
                                _timeLeft.inSeconds > 0 &&
                                !global.isReviewMode) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Module switching disabled until timeout",
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _activeModule = m;
                              if (!global.isReviewMode) {
                                // Jump to first question of this module during quiz
                                i = global.quizData.indexWhere(
                                  (q) =>
                                      (q['subject']?.toString() ?? 'General') ==
                                      m,
                                );
                                switchState();
                              }
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

            // Horizontal Navigation dots (Filtered by module or sequence)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: (global.isReviewMode && _activeModule == "All")
                    ? _displaySequence.length
                    : moduleIndices.length,
                itemBuilder: (context, index) {
                  int globalIndex =
                      (global.isReviewMode && _activeModule == "All")
                      ? _displaySequence[index]
                      : moduleIndices[index];
                  return GestureDetector(
                    onTap:
                        (global.perQuestionTime > 0 &&
                            globalIndex < i &&
                            !global.isReviewMode)
                        ? null
                        : () {
                            setState(() {
                              i = globalIndex;
                              switchState();
                            });
                          },
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: _getQuestionDecoration(
                        globalIndex,
                        isCurrent: i == globalIndex,
                      ),
                      child: Center(
                        child: Text(
                          _getDisplayNumber(globalIndex),
                          style: TextStyle(
                            color:
                                (global.perQuestionTime > 0 &&
                                    globalIndex < i &&
                                    !global.isReviewMode)
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  color:
                      (global.isReviewMode &&
                          _getQuestionColor(i) != Colors.transparent)
                      ? _getQuestionColor(i).withValues(alpha: 0.05)
                      : global.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color:
                          (global.isReviewMode &&
                              _getQuestionColor(i) != Colors.transparent)
                          ? _getQuestionColor(i).withValues(alpha: 0.5)
                          : global.borderColor,
                      width:
                          (global.isReviewMode &&
                              _getQuestionColor(i) != Colors.transparent)
                          ? 2
                          : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: global.labelColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Q${_getDisplayNumber(i)}",
                                    style: GoogleFonts.poppins(
                                      color: global.labelColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: global.primaryAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (question['type'] ?? 'Single Choice')
                                        .toString()
                                        .toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: global.primaryAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                if (!global.isReviewMode &&
                                    global.attemptLimits['type'] != 'none')
                                  _buildLimitStatusIndicatorAtIndex(i),
                                const SizedBox(width: 8),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.report_gmailerrorred_rounded,
                                    color: global.errorColor,
                                    size: 20,
                                  ),
                                  onPressed: () => _showReportDialog(i),
                                  tooltip: "Report Question",
                                ),
                              ],
                            ),
                            if (global.isReviewMode)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_getMarksForQuestion(i) > 0
                                              ? global.successColor
                                              : (_getMarksForQuestion(i) < 0
                                                    ? global.errorColor
                                                    : global.labelColor))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${_getMarksForQuestion(i) > 0 ? '+' : ''}${_getMarksForQuestion(i)} Marks",
                                  style: GoogleFonts.poppins(
                                    color: _getMarksForQuestion(i) > 0
                                        ? global.successColor
                                        : (_getMarksForQuestion(i) < 0
                                              ? global.errorColor
                                              : global.labelColor),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${(question["Q"] as Map?)?['text'] ?? ""}",
                          style: GoogleFonts.poppins(
                            color: global.valueColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...buttonsData(i),
                        if (global.isReviewMode &&
                            global.solutions.containsKey(
                              question['uid']?.toString() ?? "",
                            ))
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: global.bgColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: global.primaryAccent.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline,
                                      color: global.primaryAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "SOLUTION",
                                      style: GoogleFonts.poppins(
                                        color: global.primaryAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  global.solutions[question['uid']
                                          ?.toString()] ??
                                      "",
                                  style: GoogleFonts.poppins(
                                    color: global.valueColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!global.isReviewMode) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: global.quizResult[i][4] == true
                                          ? global.reviewColor
                                          : global.borderColor,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    foregroundColor:
                                        global.quizResult[i][4] == true
                                        ? global.reviewColor
                                        : global.labelColor,
                                  ),
                                  onPressed: () => setState(() {
                                    global.quizResult[i][4] =
                                        !(global.quizResult[i][4] as bool);
                                  }),
                                  icon: Icon(
                                    global.quizResult[i][4] == true
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "REVIEW",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: global.errorColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => setState(() {
                                    global.quizResult[i][2] = <String>[];
                                    if (currentData["type"] == "Integer") {
                                      _integerController.clear();
                                    }
                                  }),
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "CLEAR",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).padding.bottom + 10,
          ),
          decoration: const BoxDecoration(
            color: global.cardColor,
            border: Border(top: BorderSide(color: global.borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed:
                    (global.isReviewMode
                        ? (_displaySequence.indexOf(i) <= 0)
                        : isFirst)
                    ? null
                    : () {
                        setState(() {
                          if (global.isReviewMode) {
                            int currentPos = _displaySequence.indexOf(i);
                            i = _displaySequence[currentPos - 1];
                          } else {
                            i--;
                          }
                          _activeModule =
                              global.quizData[i]['subject']?.toString() ??
                              'General';
                          switchState();
                        });
                      },
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: global.valueColor,
                disabledColor: global.labelColor.withValues(alpha: 0.3),
              ),
              Text(
                "Question ${(global.isReviewMode ? _displaySequence.indexOf(i) : i) + 1} of ${global.quizData.length}",
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 14,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (global.isReviewMode
                          ? (_displaySequence.indexOf(i) ==
                                _displaySequence.length - 1)
                          : isLast)
                      ? global.btnColor
                      : global.primaryAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  if (global.isReviewMode) {
                    int currentPos = _displaySequence.indexOf(i);
                    if (currentPos == _displaySequence.length - 1) {
                      _showSubmitConfirmation();
                    } else {
                      setState(() {
                        i = _displaySequence[currentPos + 1];
                        _activeModule =
                            global.quizData[i]['subject']?.toString() ??
                            'General';
                        switchState();
                      });
                    }
                  } else if (isLast) {
                    _showSubmitConfirmation();
                  } else {
                    setState(() {
                      i++;
                      _activeModule =
                          global.quizData[i]['subject']?.toString() ??
                          'General';
                      switchState();
                    });
                  }
                },
                child: Text(
                  (global.isReviewMode
                          ? (_displaySequence.indexOf(i) ==
                                _displaySequence.length - 1)
                          : isLast)
                      ? (global.isReviewMode ? "FINISH" : "SUBMIT")
                      : "NEXT",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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

class ButtonsOpt extends StatelessWidget {
  final VoidCallback onPressed;
  final String optUid;
  final String optText;
  final String type;
  final List<dynamic> quizResultChunk;
  final bool isLimitReached;

  const ButtonsOpt(
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
    if (sel is List) return sel.map((e) => e.toString()).toList();
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final selectionList = _getSelection();
    final bool isSelected = selectionList.contains(optUid);
    final String qUid = quizResultChunk[1].toString();
    final bool isCorrect =
        global.correctAnswers[qUid]?.contains(optUid) ?? false;
    final bool isBlocked = isLimitReached && !isSelected;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: (global.isReviewMode || isBlocked)
            ? null
            : () {
                if (type == "Single Choice") {
                  quizResultChunk[2] = [optUid];
                } else {
                  final sel = _getSelection();
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
                    ? Colors.green.withValues(alpha: 0.15)
                    : (isSelected
                          ? global.errorColor.withValues(alpha: 0.1)
                          : global.cardColor))
              : (isSelected
                    ? global.primaryAccent.withValues(alpha: 0.2)
                    : (isBlocked
                          ? global.bgColor.withValues(alpha: 0.5)
                          : global.cardColor)),
          foregroundColor: global.isReviewMode
              ? (isCorrect
                    ? Colors.greenAccent
                    : (isSelected ? global.errorColor : global.valueColor))
              : (isSelected
                    ? global.primaryAccent
                    : (isBlocked ? global.hintColor : global.valueColor)),
          side: BorderSide(
            color: global.isReviewMode
                ? (isCorrect
                      ? Colors.greenAccent
                      : (isSelected ? global.errorColor : global.borderColor))
                : (isSelected
                      ? global.primaryAccent
                      : (isBlocked ? global.bgColor : global.borderColor)),
            width: (isSelected || (global.isReviewMode && isCorrect)) ? 2.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
                      fontWeight:
                          ((global.isReviewMode && isCorrect) || isSelected)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (global.isReviewMode) ...[
                    if (isCorrect && isSelected)
                      const Text(
                        "Correct choice",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (isCorrect)
                      const Text(
                        "Correct answer",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      )
                    else if (isSelected)
                      Text(
                        "Your incorrect choice",
                        style: TextStyle(
                          color: global.errorColor,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (global.isReviewMode) ...[
              if (isCorrect)
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 20,
                )
              else if (isSelected)
                Icon(Icons.cancel, color: global.errorColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/ai_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

import '../../widgets/text_container.dart';

class ResultScreen extends StatefulWidget {
  final String? quizId;
  final String? attemptId;
  final Map<String, dynamic>? attemptAnswers;
  final List<dynamic>? attemptReviewItems;
  final List<dynamic>? attemptQuestionOrder;
  final List<dynamic>? attemptVisitedItems;
  final bool isDeleted;

  const ResultScreen({
    super.key,
    this.quizId,
    this.attemptId,
    this.attemptAnswers,
    this.attemptReviewItems,
    this.attemptQuestionOrder,
    this.attemptVisitedItems,
    this.isDeleted = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int totalMarks = 0;
  int _maxMarks = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _unattemptedCount = 0;
  bool _isLoading = true;
  String _loadingMessage = "Processing...";

  // bool _showDetails = false;
  Map<String, List<String>> _correctAnswers = {};
  Map<String, String> _solutions = {};
  List<Map<String, dynamic>> _displayQuizData = [];
  List<Map<String, dynamic>> _calculatedResults = [];
  Map<String, dynamic> _markingScheme = {"type": "default"};
  String _quizId = "";
  String? _activeResultModule;

  // AI Analysis State
  bool _isAnalyzing = false;
  Map<String, dynamic>? _aiAnalysis;
  List<dynamic>? _aiTraces;
  String? _responseId;

  @override
  void initState() {
    super.initState();
    _loadAnswersAndCalculateScore();
  }

  Future<void> _loadAnswersAndCalculateScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      Map<String, dynamic> userAnswers = {};
      List<List<dynamic>> displayQuizResult = [];

      if (widget.quizId != null && widget.attemptAnswers != null) {
        // VIEWING PAST ATTEMPT
        setState(() => _loadingMessage = "Fetching result...");
        _quizId = widget.quizId!;
        _responseId = widget.attemptId; // Capture passed ID
        userAnswers = widget.attemptAnswers!;
        final List<String> reviewUids = widget.attemptReviewItems != null
            ? List<String>.from(widget.attemptReviewItems!)
            : [];
        final List<String> questionOrder = widget.attemptQuestionOrder != null
            ? List<String>.from(widget.attemptQuestionOrder!)
            : [];
        final List<String> visitedUids = widget.attemptVisitedItems != null
            ? List<String>.from(widget.attemptVisitedItems!)
            : [];

        // Fetch quiz data (questions)
        final quiz = await global.db.readDatabase(_quizId, userId: user.uid);
        _displayQuizData = [];
        final List<dynamic> rawModules = quiz['modules'] as List? ?? [];
        final List<Map<String, dynamic>> allQuestions = [];
        global.originalQuestionOrder = [];

        for (var module in rawModules) {
          final String subject = module['subject']?.toString() ?? 'General';
          final List<dynamic> moduleData = module['data'] as List? ?? [];
          for (var q in moduleData) {
            final qMap = Map<String, dynamic>.from(q);
            qMap['subject'] = subject; // Inject subject into question
            allQuestions.add(qMap);
            final qId = (qMap['Q']?['id'] ?? qMap['uid']).toString();
            global.originalQuestionOrder.add(qId);
          }
        }

        // REORDER based on questionOrder if available
        if (questionOrder.isNotEmpty) {
          for (var qUid in questionOrder) {
            try {
              final q = allQuestions.firstWhere(
                (element) =>
                    (element['Q']?['id'] ?? element['uid']).toString() == qUid,
              );
              _displayQuizData.add(q);
            } catch (_) {}
          }
          // Add any missing questions
          for (var q in allQuestions) {
            final id = (q['Q']?['id'] ?? q['uid']).toString();
            if (!questionOrder.contains(id)) _displayQuizData.add(q);
          }
        } else {
          _displayQuizData = allQuestions;
        }

        _markingScheme = quiz['markingScheme'] ?? {"type": "default"};

        // Build displayQuizResult from quiz data and userAnswers
        for (var q in _displayQuizData) {
          final qMap = q['Q'] as Map?;
          final qId = (qMap?['id'] ?? q['uid'] ?? q['id']).toString();
          final qText = (qMap?['text'] ?? q['question'] ?? q['text'] ?? '')
              .toString();

          final selections = userAnswers[qId] is List
              ? List<String>.from(userAnswers[qId])
              : (userAnswers[qId] != null
                    ? [userAnswers[qId].toString()]
                    : <String>[]);

          final bool isReview = reviewUids.contains(qId);
          final bool isVisited = visitedUids.contains(qId);
          displayQuizResult.add([
            qText,
            qId,
            selections,
            isVisited,
            isReview,
          ]); // text, id, selections, visited, review
        }

        // Fetch correct answers
        final response = await global.db.getQuizAnswers(_quizId, user.uid);
        _correctAnswers = response['answers'];
        _solutions = response['solutions'];
      } else {
        // JUST FINISHED QUIZ (Using Global)
        setState(() => _loadingMessage = "Submitting attempt...");
        _quizId = global.id;
        _displayQuizData = List<Map<String, dynamic>>.from(global.quizData);
        displayQuizResult = List<List<dynamic>>.from(global.quizResult);
        _markingScheme = global.markingScheme;

        List<String> reviewItems = [];
        List<String> questionOrder = [];
        List<String> visitedItems = [];
        for (var result in displayQuizResult) {
          final String qUid = result[1];
          final List<String> selections = (result[2] as List).cast<String>();
          final bool isVisited = result.length > 3 ? result[3] : false;
          final bool isReview = result.length > 4 ? result[4] : false;
          userAnswers[qUid] = selections;
          questionOrder.add(qUid);
          if (isReview) reviewItems.add(qUid);
          if (isVisited) visitedItems.add(qUid);
        }

        // Fetch answers and SUBMIT attempt in one call
        final response = await global.db.getQuizAnswers(
          _quizId,
          user.uid,
          totalQuestions: displayQuizResult.length,
          userAnswers: userAnswers,
          reviewItems: reviewItems,
          questionOrder: questionOrder,
          visitedItems: visitedItems,
        );
        _correctAnswers = response['answers'];
        _solutions = response['solutions'];

        // Extract server-side results
        if (response.containsKey('submission')) {
          final sub = response['submission'] as Map<String, dynamic>;
          _responseId = sub['id']; // Capture the response ID
          totalMarks = (sub['score'] ?? 0).toInt();
          _maxMarks = (sub['maxPossible'] ?? 0).toInt();
          _correctCount = (sub['correctCount'] ?? 0).toInt();
          _wrongCount = (sub['wrongCount'] ?? 0).toInt();
          _unattemptedCount = (sub['unattemptedCount'] ?? 0).toInt();
        }
      }

      int total = 0;
      int maxPoints = 0;
      int correct = 0;
      int wrong = 0;
      int unattempted = 0;
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
          final config =
              pqt[type] ?? pqt['Single Choice'] ?? {'correct': 4, 'wrong': -1};
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
        final List<String> selections = (resultDataset[2] as List)
            .cast<String>();
        final bool isReview = resultDataset.length > 4
            ? resultDataset[4]
            : false;

        // Find correct option UIDs
        final List<String> answers = _correctAnswers[qUid] ?? [];

        // Find question type
        String? qType;
        String? qSubject;
        try {
          final qDoc = _displayQuizData.firstWhere(
            (q) => (q['Q']?['id'] ?? q['uid']) == qUid,
          );
          qType = qDoc['type'];
          qSubject = qDoc['subject']?.toString();
        } catch (_) {}

        final marking = getMarking(qType, qUid);
        maxPoints += marking['correct']!;

        int questionMark = 0;
        bool isCorrect = false;
        bool isActuallyAnswered = selections.isNotEmpty;

        // For Integer questions, treat empty string as unattempted
        if (isActuallyAnswered && qType == "Integer") {
          if (selections.first.toString().trim().isEmpty) {
            isActuallyAnswered = false;
          }
        }

        if (!isActuallyAnswered) {
          questionMark = 0;
          unattempted++;
        } else {
          if (qType == "Integer") {
            final String userVal = selections.first.toString().trim();
            final String correctVal = answers.isNotEmpty
                ? answers.first.trim()
                : "";
            if (userVal == correctVal) {
              questionMark = marking['correct']!;
              isCorrect = true;
            } else {
              questionMark = marking['wrong']!;
            }
          } else if (selections.length == answers.length &&
              selections.every((s) => answers.contains(s))) {
            questionMark = marking['correct']!;
            isCorrect = true;
          } else {
            questionMark = marking['wrong']!;
          }

          if (isCorrect) {
            correct++;
          } else {
            wrong++;
          }
        }

        total += questionMark;

        _calculatedResults.add({
          'text': qText,
          'uid': qUid,
          'selections': isActuallyAnswered ? selections : <String>[],
          'answers': answers,
          'mark': questionMark,
          'maxMark': marking['correct'], // Added maxMark
          'type': qType,
          'subject': qSubject ?? 'General',
          'isReview': isReview,
          'isVisited': resultDataset.length > 3
              ? resultDataset[3] == true
              : true,
          'solution': _solutions[qUid] ?? '',
          'originalIndex': i, // Added to fix review navigation
        });
      }

      setState(() {
        totalMarks = total;
        _maxMarks = maxPoints;
        _correctCount = correct;
        _wrongCount = wrong;
        _unattemptedCount = unattempted;
        _isLoading = false;
        _activeResultModule = "All";
      });
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text("Error fetching answers: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAiAnalysis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final response = await AiService().analyzeAttempt(
        userId: user.uid,
        userEmail: user.email ?? 'unknown',
        userName: global.currentUserProfile?['name'] ?? user.displayName ?? 'User',
        quizId: _quizId,
        responseId: _responseId ?? '', // Use captured ID
      );

      if (mounted) {
        setState(() {
          _aiAnalysis = response['analysis'];
          _aiTraces = response['traces'];
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Analysis Error: $e"),
            backgroundColor: global.errorColor,
          ),
        );
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _startReview({int index = 0}) {
    global.isReviewMode = true;
    global.reviewInitialIndex = index;
    global.correctAnswers = _correctAnswers;
    global.solutions = _solutions;
    // Ensure global quiz data is synced with what we have here
    global.quizData = _displayQuizData
        .map((e) => Map<String, Object>.from(e))
        .toList();

    // Map _calculatedResults back to global.quizResult format
    // [qText, qUid, selectionList, visitedBool, reviewBool]
    global.quizResult = _calculatedResults.map((res) {
      return [
        res['text'],
        res['uid'],
        res['selections'],
        res['isVisited'] ?? true, // visited
        res['isReview'] ?? false, // review
      ];
    }).toList();

    Navigator.pushNamed(context, "/Quiz");
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please wait while your result is being processed...",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: global.primaryAccent,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Quiz Result",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: global.valueColor,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: !_isLoading,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: global.primaryAccent,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _buildSummaryView(),
      ),
    );
  }

  Widget _buildSummaryView() {
    final double percentage = _maxMarks > 0
        ? (totalMarks / _maxMarks) * 100
        : 0;
    final int threshold = (_markingScheme['passThreshold'] ?? 40).toInt();
    final bool isPassed = percentage >= threshold;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.isDeleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: global.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: global.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_forever,
                    color: global.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This attempt has been soft-deleted and is visible only to administrators.",
                      style: GoogleFonts.poppins(
                        color: global.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Card(
            color: global.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isPassed ? global.successColor : global.errorColor,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                MarksPanel(
                  totalCorrectAnswers: totalMarks,
                  totalQuestions: _maxMarks,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isPassed ? global.successColor : global.errorColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPassed
                        ? "PASSED ($threshold% Req.)"
                        : "FAILED ($threshold% Req.)",
                    style: GoogleFonts.poppins(
                      color: isPassed ? global.successColor : global.errorColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (global.featureFlags?['enable_export'] == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        // Implement Export logic here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Exporting results...")),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text("EXPORT ATTEMPT"),
                      style: TextButton.styleFrom(
                        foregroundColor: global.primaryAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: global.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: global.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                    "Correct",
                    _correctCount,
                    global.successColor,
                  ),
                  _buildSummaryStat("Wrong", _wrongCount, global.errorColor),
                  _buildSummaryStat(
                    "Skipped",
                    _unattemptedCount,
                    global.warningColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildAiFeedbackPanel(),
          const SizedBox(height: 24),
          _buildModularBreakdown(),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _startReview(index: 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: global.btnColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text(
              "SEE ATTEMPT DETAILS",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              "/home",
              (r) => false,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: global.valueColor,
              minimumSize: const Size(double.infinity, 56),
              side: const BorderSide(color: global.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text("BACK TO HOME"),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
        ],
      ),
    );
  }

  Widget _buildAiFeedbackPanel() {
    final bool hasPrivacyAccepted = global.currentUserProfile?['optInAiAnalysis'] == true;

    if (_aiAnalysis == null) {
      return Column(
        children: [
          OutlinedButton.icon(
            onPressed: (_isAnalyzing || !hasPrivacyAccepted) ? null : _fetchAiAnalysis,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              side: BorderSide(color: hasPrivacyAccepted ? global.primaryAccent : global.hintColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isAnalyzing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.auto_awesome, color: hasPrivacyAccepted ? global.primaryAccent : global.hintColor),
            label: Text(
              _isAnalyzing ? "ANALYZING PERFORMANCE..." : "DEEP ANALYZE WITH AI",
              style: GoogleFonts.poppins(
                color: hasPrivacyAccepted ? global.primaryAccent : global.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!hasPrivacyAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Accept AI & Personalization policy in Profile to enable deep analysis.",
                style: GoogleFonts.poppins(color: global.labelColor, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    final String rating = _aiAnalysis!['rating'] ?? "Learner";
    final String commentary = _aiAnalysis!['overallCommentary'] ?? "No commentary provided.";
    final List<dynamic> subjectPerformance = _aiAnalysis!['subjectPerformance'] ?? [];
    final List<dynamic> strengths = _aiAnalysis!['strengths'] ?? [];
    final List<dynamic> weaknesses = _aiAnalysis!['weaknesses'] ?? [];
    final List<dynamic> recommendations = _aiAnalysis!['recommendations'] ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: global.primaryAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: global.primaryAccent.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: global.primaryAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: global.valueColor,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) => const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16,
                      )),
                    ),
                  ],
                ),
              ),
              if (global.adminLevel == 0)
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: global.labelColor, size: 20),
                  onPressed: _showTracesDialog,
                  tooltip: "Server Traces",
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            commentary,
            style: GoogleFonts.poppins(color: global.valueColor, fontSize: 14, height: 1.6),
          ),
          if (subjectPerformance.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel("SUBJECT BREAKDOWN"),
            const SizedBox(height: 12),
            ...subjectPerformance.map((s) => _buildSubjectCard(s)),
          ],
          if (strengths.isNotEmpty || weaknesses.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel("SKILL PROFILE"),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...strengths.map((s) => _buildAnalysisChip(s.toString(), global.successColor)),
                ...weaknesses.map((w) => _buildAnalysisChip(w.toString(), Colors.orangeAccent)),
              ],
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel("RECOMMENDATIONS"),
            const SizedBox(height: 12),
            ...recommendations.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: global.primaryAccent, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      r.toString(),
                      style: GoogleFonts.poppins(color: global.valueColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSubjectCard(dynamic data) {
    final s = data as Map;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s['subject'] ?? "General",
                style: const TextStyle(color: global.valueColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                s['accuracy'] ?? "0%",
                style: const TextStyle(color: global.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s['feedback'] ?? "",
            style: TextStyle(color: global.labelColor, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showTracesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text("Server Execution Traces", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _aiTraces?.length ?? 0,
            itemBuilder: (context, index) {
              final trace = _aiTraces![index] as Map;
              Color color = global.labelColor;
              if (trace['type'] == 'success') color = Colors.greenAccent;
              if (trace['type'] == 'error') color = Colors.redAccent;
              if (trace['type'] == 'warning') color = Colors.orangeAccent;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trace['source']?.toString().toUpperCase() ?? "UNKNOWN",
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          trace['type']?.toString().toUpperCase() ?? "",
                          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trace['message'] ?? "",
                      style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  Widget _buildModularBreakdown() {
    final Map<String, List<Map<String, dynamic>>> moduleGroups = {};
    for (var res in _calculatedResults) {
      final subject = res['subject'] ?? 'General';
      moduleGroups.putIfAbsent(subject, () => []).add(res);
    }

    final modules = moduleGroups.keys.toList();
    if (modules.isEmpty) return const SizedBox.shrink();

    final List<String> displayModules = ["All", ...modules];
    _activeResultModule ??= "All";

    final activeGroup = _activeResultModule == "All"
        ? _calculatedResults
        : (moduleGroups[_activeResultModule] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "QUIZ PERFORMANCE OVERVIEW",
          style: GoogleFonts.poppins(
            color: global.primaryAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (displayModules.length > 1)
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayModules.length,
              itemBuilder: (context, index) {
                final m = displayModules[index];
                final isSelected = _activeResultModule == m;
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
                        setState(() => _activeResultModule = m);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: global.borderColor),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeGroup.length,
                  itemBuilder: (context, idx) {
                    final res = activeGroup[idx];
                    return GestureDetector(
                      onTap: () =>
                          _startReview(index: res['originalIndex'] ?? idx),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildQuestionStatusDot(res, idx + 1),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildLegend(),
              ),
              const Divider(color: global.borderColor, height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildModuleSummaryStats(activeGroup),
              ),
            ],
          ),
        ),
      ],
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            displayIndex.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          displayIndex.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legendItem(Colors.green, "Correct"),
            _legendItem(global.errorColor, "Incorrect"),
            _legendItem(global.reviewColor, "Review"),
            _legendItem(Colors.grey, "Unattempted"),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildModuleSummaryStats(List<Map<String, dynamic>> group) {
    int moduleScore = 0;
    int moduleMax = 0;
    int correct = 0;
    int wrong = 0;
    int skipped = 0;

    for (var res in group) {
      final mark = res['mark'] as int;
      final selections = res['selections'] as List;

      if (selections.isEmpty) {
        skipped++;
      } else if (mark > 0) {
        correct++;
      } else {
        wrong++;
      }
      moduleScore += mark;
      moduleMax += (res['maxMark'] as int? ?? 4);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSmallStat(
          "Score",
          "$moduleScore/$moduleMax",
          global.primaryAccent,
        ),
        _buildSmallStat("Correct", "$correct", global.successColor),
        _buildSmallStat("Wrong", "$wrong", global.errorColor),
        _buildSmallStat("Skipped", "$skipped", global.warningColor),
      ],
    );
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

  Widget _buildSummaryStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 12),
        ),
      ],
    );
  }
}

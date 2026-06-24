import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/widgets/quiz_widgets.dart';

class QuizDetailsScreen extends StatefulWidget {
  final String quizId;

  const QuizDetailsScreen({super.key, required this.quizId});

  @override
  State<QuizDetailsScreen> createState() => _QuizDetailsScreenState();
}

class _QuizDetailsScreenState extends State<QuizDetailsScreen> {
  User? _user;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _creatorProfile;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _canManage = false;
  bool _isStartingQuiz = false;
  Map<String, dynamic>? _quizData;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchQuizDetails();
  }

  Future<void> _fetchQuizDetails() async {
    try {
      final db = DatabaseService();
      final aggregatedData = await db.fetchAggregatedQuizDetails(
        widget.quizId,
        userId: _user?.uid,
      );

      setState(() {
        _quizData = aggregatedData;
        _creatorProfile = aggregatedData['creatorProfile'];
        _userProfile = aggregatedData['userProfile'];
        _isAdmin = aggregatedData['isAdmin'] ?? false;
        _canManage = aggregatedData['canManage'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().contains("permission")
            ? "Access Denied: This quiz is private."
            : "Error: $e";

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
        Navigator.pop(context);
      }
    }
  }

  Future<bool?> _showBypassDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.primaryAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("BYPASS"),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    bool demoAnswered = false;
    bool demoReview = false;
    String? selectedOption;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Color getDemoDotColor() {
            if (demoReview && demoAnswered) return global.reviewColor;
            if (demoReview) return global.reviewColor;
            if (demoAnswered) return global.successColor;
            return global.infoColor;
          }

          return AlertDialog(
            backgroundColor: global.cardColor,
            title: Text(
              "How it Works",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: global.valueColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHelpSection(
                    "Interactive Demo",
                    "Try this sample question to see how colors change.",
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: global.bgColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: global.borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: getDemoDotColor(),
                                gradient: (demoReview && demoAnswered)
                                    ? const LinearGradient(
                                        colors: [
                                          global.reviewColor,
                                          global.successColor,
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Q1 Status",
                              style: GoogleFonts.poppins(
                                color: global.labelColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "What is the capital of France?",
                          style: GoogleFonts.poppins(
                            color: global.valueColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...["Paris", "London"].map((opt) {
                          bool isSelected = selectedOption == opt;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedOption = isSelected ? null : opt;
                                  demoAnswered = selectedOption != null;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? global.primaryAccent
                                        : global.borderColor,
                                  ),
                                  color: isSelected
                                      ? global.primaryAccent.withOpacity(0.1)
                                      : Colors.transparent,
                                ),
                                child: Text(
                                  opt,
                                  style: GoogleFonts.poppins(
                                    color: isSelected
                                        ? global.primaryAccent
                                        : global.labelColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const Divider(color: global.borderColor),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "Review",
                              style: GoogleFonts.poppins(
                                color: global.labelColor,
                                fontSize: 12,
                              ),
                            ),
                            Switch(
                              value: demoReview,
                              activeColor: global.reviewColor,
                              onChanged: (v) {
                                setDialogState(() => demoReview = v);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "COLOR GUIDE",
                    style: GoogleFonts.poppins(
                      color: global.primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildColorGuideRow(
                    global.infoColor,
                    "Current or seen question.",
                  ),
                  _buildColorGuideRow(
                    global.successColor,
                    "Answered question.",
                  ),
                  _buildColorGuideRow(global.reviewColor, "Marked for review."),
                  _buildColorGuideRow(
                    global.reviewColor,
                    "Answered and marked for review.",
                    secondaryColor: global.successColor,
                  ),
                  const SizedBox(height: 20),
                  _buildHelpSection(
                    "Navigation",
                    "• Swipe left/right or use the dots to move.\n"
                        "• The 'Review & Next' button marks for later thought.",
                  ),
                  const SizedBox(height: 16),
                  _buildHelpSection(
                    "Rules",
                    "• Timer auto-submits your answers.\n"
                        "• Per Question timers disable backward navigation.",
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("GOT IT"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildColorGuideRow(
    Color primary,
    String text, {
    Color? secondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: secondaryColor != null
                  ? LinearGradient(
                      colors: [primary, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: secondaryColor == null ? primary : null,
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: global.labelColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            color: global.primaryAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: GoogleFonts.poppins(
            color: global.labelColor,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleVisibility() async {
    if (_quizData == null || _user == null) return;

    final currentVisibility = _quizData!['visibility'] ?? 'private';
    final newVisibility = currentVisibility == 'public' ? 'private' : 'public';

    try {
      await DatabaseService().updateDatabase(
        docId: _quizData!['id'],
        currentUserId: _user!.uid,
        visibility: newVisibility,
        isAiGenerated: _quizData!['isAiGenerated'] ?? false,
      );

      setState(() {
        _quizData!['visibility'] = newVisibility;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Quiz is now $newVisibility")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _toggleLock() async {
    if (_quizData == null || _user == null) return;

    final bool currentLocked = _quizData!['isLocked'] ?? false;
    final bool newLocked = !currentLocked;

    try {
      await DatabaseService().toggleQuizLock(
        docId: _quizData!['id'],
        currentUserId: _user!.uid,
        isLocked: newLocked,
      );

      setState(() {
        _quizData!['isLocked'] = newLocked;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newLocked ? "Quiz Locked" : "Quiz Unlocked")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _quizData?['title'] ?? 'Loading Quiz...';
    final description =
        _quizData?['description'] ?? 'Please wait while we fetch the details.';
    final timeLimit = _quizData != null
        ? "${(_quizData!['time'] ?? 0) ~/ 60} Minutes"
        : "--";
    final totalQuestions = _quizData != null
        ? _calculateTotalQuestions().toString()
        : "--";
    final creator =
        _creatorProfile?['name'] ??
        _creatorProfile?['email'] ??
        (_isLoading ? "Loading..." : "Unknown");

    return Stack(
      children: [
        Scaffold(
          backgroundColor: global.bgColor,
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: global.valueColor,
              ),
            ),
            iconTheme: const IconThemeData(color: global.valueColor),
            actions: [if (_isAdmin) const AdminBadge()],
          ),
          body: _isLoading && _quizData == null
              ? const Center(
                  child: CircularProgressIndicator(color: global.primaryAccent),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          VisibilityBadge(
                            visibility: _quizData?['visibility'] ?? 'private',
                            isLocked: _quizData?['isLocked'] ?? false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _quizData == null
                                  ? null
                                  : () {
                                      final link =
                                          "https://thinkfast3834.web.app/quiz?id=${_quizData!['id']}";
                                      Clipboard.setData(
                                        ClipboardData(text: link),
                                      ).then((_) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Quiz link copied!",
                                              ),
                                            ),
                                          );
                                        }
                                      });
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: global.borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.link_rounded,
                                      size: 18,
                                      color: global.primaryAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _quizData == null
                                            ? "thinkfast.app/quiz?id=..."
                                            : "thinkfast3834.web.app/quiz?id=${_quizData!['id']}",
                                        style: GoogleFonts.poppins(
                                          color: global.labelColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.copy_all_rounded,
                                      size: 16,
                                      color: global.labelColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: global.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: global.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InfoRow(label: "Description", value: description),
                            const Divider(
                              color: global.borderColor,
                              height: 32,
                            ),
                            InfoRow(
                              label: "Duration",
                              value: timeLimit,
                              icon: Icons.timer_outlined,
                            ),
                            InfoRow(
                              label: "Total Questions",
                              value: totalQuestions,
                              icon: Icons.quiz_outlined,
                            ),
                            InfoRow(
                              label: "Created By",
                              value: creator,
                              icon: Icons.person_outline,
                            ),
                            if (_quizData != null &&
                                _quizData!['activeAt'] != null)
                              InfoRow(
                                label: "Scheduled For",
                                value:
                                    "${(_quizData!['activeAt'] as Timestamp).toDate().day}/${(_quizData!['activeAt'] as Timestamp).toDate().month} ${(_quizData!['activeAt'] as Timestamp).toDate().hour}:${(_quizData!['activeAt'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}",
                                icon: Icons.calendar_today_outlined,
                              ),
                            if (_quizData != null &&
                                _quizData!['isRestricted'] == true)
                              InfoRow(
                                label: "Access",
                                value: "Restricted (Allowed List Only)",
                                icon: Icons.lock_person_outlined,
                              ),
                            if (_quizData != null &&
                                _quizData!['category'] != null)
                              InfoRow(
                                label: "Category",
                                value: _quizData!['category'].toString(),
                                icon: Icons.category_outlined,
                              ),
                            if (_quizData != null &&
                                _quizData!['difficulty'] != null)
                              InfoRow(
                                label: "Difficulty",
                                value: _quizData!['difficulty'].toString(),
                                icon: Icons.speed,
                              ),
                            if (_quizData != null &&
                                _quizData!['marks'] != null)
                              InfoRow(
                                label: "Marks",
                                value: _quizData!['marks'].toString(),
                                icon: Icons.star_outline,
                              ),
                            const Divider(
                              color: global.borderColor,
                              height: 32,
                            ),
                            _buildQuizTypeSection(),
                            const Divider(
                              color: global.borderColor,
                              height: 32,
                            ),
                            _buildMarkingSchemeInfo(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_isLoading || _quizData != null)
                        _buildActionButtons(),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 40,
                      ),
                    ],
                  ),
                ),
        ),
        if (_isStartingQuiz)
          Positioned.fill(
            child: Material(
              color: global.bgColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: global.primaryAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "PREPARING QUIZ...",
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Validating Session & Environment",
                      style: GoogleFonts.poppins(
                        color: global.labelColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuizTypeSection() {
    if (_quizData == null) return const SizedBox.shrink();

    final List<String> types = [];

    // Directly identifying Quiz Type from stored metadata
    final int perQ = _quizData!['perQuestionTime'] ?? 0;
    if (perQ > 0) types.add("Rapid Fire ($perQ s/Q)");

    if (_quizData!['markingType'] == 'per_question') types.add("Per Q Marking");

    final int modCount = _quizData!['moduleCount'] ?? 0;
    if (modCount > 1) types.add("Modular Quiz");

    if ((_quizData!['time'] ?? 0) == 0) types.add("Unlimited Duration");

    final String alt = _quizData!['attemptLimitType'] ?? 'none';
    if (alt != 'none') {
      types.add("Select N out of M");
    }

    if (types.isEmpty) types.add("Standard Quiz");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "QUIZ TYPE",
          style: GoogleFonts.poppins(
            color: global.labelColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types
              .map(
                (t) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: global.primaryAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: global.primaryAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    t,
                    style: GoogleFonts.poppins(
                      color: global.primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMarkingSchemeInfo() {
    if (_quizData == null) return const SizedBox.shrink();
    final type = _quizData!['markingType'] ?? 'default';
    final scheme = _quizData!['markingScheme'] as Map? ?? {"type": "default"};

    String label = "Marking Details";
    List<Widget> rows = [];

    if (type == 'default') {
      rows.add(_schemeRow("Correct", "+4", global.successColor));
      rows.add(_schemeRow("Incorrect", "-1", global.errorColor));
    } else if (type == 'entire_quiz') {
      final globalS = scheme['global'] as Map? ?? {};
      rows.add(
        _schemeRow(
          "Correct",
          "+${globalS['correct'] ?? 4}",
          global.successColor,
        ),
      );
      rows.add(
        _schemeRow("Incorrect", "${globalS['wrong'] ?? -1}", global.errorColor),
      );
    } else if (type == 'per_question_type') {
      final pqt = scheme['perQuestionType'] as Map? ?? {};
      pqt.forEach((qType, values) {
        final v = values as Map? ?? {};
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              qType,
              style: GoogleFonts.poppins(
                color: global.primaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        rows.add(
          _schemeRow("Correct", "+${v['correct'] ?? 4}", global.successColor),
        );
        rows.add(
          _schemeRow("Incorrect", "${v['wrong'] ?? -1}", global.errorColor),
        );
      });
    } else if (type == 'per_question') {
      rows.add(
        Text(
          "Variable marks defined per individual question.",
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: global.labelColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _schemeRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: global.valueColor, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalQuestions() {
    if (_quizData == null) return 0;
    final int count = _quizData!['totalQuestions'] ?? 0;
    if (count > 0) return count;

    // Fallback: This quiz doc is missing totalQuestions metadata
    final List<dynamic> rawModules = _quizData!['modules'] as List? ?? [];
    return rawModules.fold<int>(0, (sum, module) {
      final List<dynamic> questions = module['data'] as List? ?? [];
      return sum + questions.length;
    });
  }

  Widget _buildRestrictedQuizAction({
    required String text,
    required VoidCallback onPressed,
    required IconData icon,
    required bool enabled,
    VoidCallback? onDoubleTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: QuizActionButton(
        text: text,
        onPressed: onPressed,
        icon: icon,
        onDoubleTap: onDoubleTap,
        enabled: enabled,
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool isOwner = _user != null && _quizData!['creatorId'] == _user!.uid;
    final bool canManage = _canManage;
    final bool isPersonal = _quizData!['isPersonal'] == true;
    final bool isAdmin = _isAdmin;
    final String quizId = _quizData!['id'];

    bool hasPerm(String perm) {
      if (isAdmin || isOwner) return true;
      final perms = global.managedQuizzes[quizId];
      return perms?[perm] == true;
    }

    return Column(
      children: [
        QuizActionButton(
          text: "How it Works",
          onPressed: _showHelpDialog,
          icon: Icons.help_outline_rounded,
        ),
        const SizedBox(height: 16),
        if (_user != null) ...[
          QuizActionButton(
            text: "View Your Attempts",
            onPressed: () {
              Navigator.pushNamed(
                context,
                "/My Attempts",
                arguments: _quizData!['id'],
              );
            },
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 16),
        ],
        QuizActionButton(
          text: "Start Quiz",
          onPressed: () async {
            setState(() => _isStartingQuiz = true);
            try {
              final db = DatabaseService();
              final String? activeQuizId = _quizData!['activeQuizId'];
              final Timestamp? activeQuizExpiry =
                  _quizData!['activeQuizExpiry'];

              if (activeQuizId != null) {
                bool isExpired = false;
                if (activeQuizExpiry != null) {
                  isExpired = activeQuizExpiry.toDate().isBefore(
                    DateTime.now(),
                  );
                }

                if (isExpired) {
                  // Auto-submit blank and clean up
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cleaning up previous expired session...'),
                    ),
                  );
                  await db.handleExpiredQuiz(_user!.uid, activeQuizId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You are already taking another quiz ($activeQuizId). Finish it first! (Double tap to instant submit previous)',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() => _isStartingQuiz = false);
                  return;
                }
              }

              if (_quizData!['isLocked'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This quiz is locked and not accepting new responses',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                setState(() => _isStartingQuiz = false);
                return;
              }

              // Scheduling Check
              if (_quizData!['activeAt'] != null) {
                final DateTime activeAt = (_quizData!['activeAt'] as Timestamp)
                    .toDate();
                if (DateTime.now().isBefore(activeAt)) {
                  if (global.isAdmin) {
                    final bool? bypass = await _showBypassDialog(
                      "Early Access",
                      "This quiz is scheduled for later. Bypass and start now?",
                    );
                    if (bypass != true) {
                      setState(() => _isStartingQuiz = false);
                      return;
                    }
                  } else {
                    final String formatted =
                        "${activeAt.day}/${activeAt.month} ${activeAt.hour}:${activeAt.minute.toString().padLeft(2, '0')}";
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'This quiz is scheduled to start at $formatted',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    setState(() => _isStartingQuiz = false);
                    return;
                  }
                }
              }

              // Restriction Check
              if (_quizData!['isRestricted'] == true) {
                final List<dynamic> allowed =
                    _quizData!['allowedParticipants'] as List? ?? [];
                if (!allowed.contains(_user?.uid)) {
                  if (global.isAdmin) {
                    final bool? bypass = await _showBypassDialog(
                      "Restricted Quiz",
                      "You are not in the allowed list. Bypass restriction?",
                    );
                    if (bypass != true) {
                      setState(() => _isStartingQuiz = false);
                      return;
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Access Denied: You are not in the allowed participants list for this quiz.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    setState(() => _isStartingQuiz = false);
                    return;
                  }
                }
              }

              final bool allowMultiple =
                  _quizData!['allowMultipleAttempts'] ?? true;
              final bool hasAttempted = _quizData!['hasAttempted'] ?? false;

              if (!allowMultiple && hasAttempted && !isOwner) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'You have already attempted this quiz. Multiple attempts are disabled.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                setState(() => _isStartingQuiz = false);
                return;
              }

              if (_user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please Login to Continue')),
                );
                Navigator.pushNamed(context, '/login');
                setState(() => _isStartingQuiz = false);
                return;
              }

              // Refresh user state to check verification
              await _user!.reload();
              _user = _auth.currentUser;

              // Ban Check
              final bool isBanned = await db.isUserBanned(
                _user!.uid,
                quizId: _quizData!['id'],
              );
              if (isBanned) {
                if (global.isAdmin) {
                  final bool? bypass = await _showBypassDialog(
                    "Banned from Quiz",
                    "You are currently banned from this quiz. As an administrator in Admin Mode, would you like to bypass this restriction?",
                  );
                  if (bypass != true) {
                    setState(() => _isStartingQuiz = false);
                    return;
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Access Denied: You have been blocked from this quiz.",
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                  setState(() => _isStartingQuiz = false);
                  return;
                }
              }

              if (!_user!.emailVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please verify your email to start the quiz'),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pushNamed(context, '/verify');
                setState(() => _isStartingQuiz = false);
                return;
              }

              if (_quizData!['visibility'] == 'public' || canManage) {
                final List<Map<String, Object>> flattenedQuestions = [];
                final List<dynamic> rawModules =
                    _quizData!['modules'] as List? ?? [];

                for (var module in rawModules) {
                  final String subject = module['subject'].toString();
                  final List<dynamic> questions = module['data'] as List? ?? [];
                  for (var q in questions) {
                    final qMap = Map<String, Object>.from(q);
                    qMap['subject'] =
                        subject; // Re-inject for flat processing in Questions screen
                    flattenedQuestions.add(qMap);
                  }
                }

                global.quizData = flattenedQuestions;

                global.ID = _quizData!['id'];
                global.time = _quizData!['time'] as int;
                global.perQuestionTime = _quizData!['perQuestionTime'] ?? 0;
                global.completeRandomShuffle =
                    _quizData!['completeRandomShuffle'] ?? false;
                global.markingScheme =
                    _quizData!['markingScheme'] ?? {"type": "default"};
                global.attemptLimits =
                    _quizData!['attemptLimits'] ?? {"type": "none"};
                global.currentUserProfile = _userProfile;
                global.creatorProfile = _creatorProfile;

                // Reset Quiz Session State
                global.isReviewMode = false;
                global.correctAnswers = {};
                global.solutions = {};

                // Mark as active quiz with expiry (Duration + 5 mins buffer)
                final int quizDurationSeconds = _quizData!['time'] as int;
                final DateTime expiry = DateTime.now().add(
                  Duration(seconds: quizDurationSeconds + 300),
                );

                await db.updateActiveQuiz(
                  uid: _user!.uid,
                  quizId: _quizData!['id'],
                  expiry: expiry,
                );

                if (mounted) {
                  setState(() => _isStartingQuiz = false);
                  Navigator.pushNamed(context, "/Quiz");
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("This quiz is private")),
                );
                setState(() => _isStartingQuiz = false);
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isStartingQuiz = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Quiz Start Error: $e")));
              }
            }
          },
          isPrimary: true,
          icon: Icons.play_arrow_rounded,
          onDoubleTap: () async {
            final db = DatabaseService();
            final String? activeQuizId = _quizData!['activeQuizId'];

            if (activeQuizId != null && _user != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Instant submitting previous session...'),
                ),
              );
              await db.handleExpiredQuiz(_user!.uid, activeQuizId);

              // Update UI state to reflect cleared active quiz
              setState(() {
                _quizData!['activeQuizId'] = null;
                _quizData!['activeQuizExpiry'] = null;
              });
            }
          },
        ),
        if (canManage) ...[
          const SizedBox(height: 16),
          _buildRestrictedQuizAction(
            text: _quizData!['visibility'] == 'public'
                ? "Make Private"
                : "Make Public",
            onPressed: _toggleVisibility,
            enabled: hasPerm('can_publish'),
            icon: _quizData!['visibility'] == 'public'
                ? Icons.lock_outline
                : Icons.public_outlined,
          ),
          _buildRestrictedQuizAction(
            text: _quizData!['isLocked'] == true ? "Unlock Quiz" : "Lock Quiz",
            onPressed: _toggleLock,
            enabled: hasPerm('can_update'),
            icon: _quizData!['isLocked'] == true
                ? Icons.lock_open_rounded
                : Icons.lock_person_rounded,
          ),
          _buildRestrictedQuizAction(
            text: "View Responses",
            onPressed: () {
              Navigator.pushNamed(
                context,
                "/Quiz Responses",
                arguments: {
                  'quizId': _quizData!['id'],
                  'quizTitle': _quizData!['title'] ?? 'Quiz',
                },
              );
            },
            enabled: hasPerm('can_view_results'),
            icon: Icons.analytics_outlined,
          ),
          _buildRestrictedQuizAction(
            text: "Manage Collaborators",
            onPressed: () {
              Navigator.pushNamed(
                context,
                "/Manage Collaborators",
                arguments: _quizData!['id'],
              );
            },
            enabled: hasPerm('can_manage_collaborators'),
            icon: Icons.people_outline,
          ),
          if (!isPersonal || isAdmin) ...[
            _buildRestrictedQuizAction(
              text: "Update Quiz",
              onPressed: () {
                final List<Map<String, Object>> flattenedQuestions = [];
                final List<dynamic> rawModules =
                    _quizData!['modules'] as List? ?? [];

                int incrementalIndex = 0;
                for (var module in rawModules) {
                  final String subject = module['subject'].toString();
                  final List<dynamic> questions = module['data'] as List? ?? [];
                  for (var q in questions) {
                    incrementalIndex++;
                    final qMap = Map<String, Object>.from(q);
                    qMap['subject'] = subject;
                    qMap['incrementalIndex'] = incrementalIndex;
                    flattenedQuestions.add(qMap);
                  }
                }

                global.quizData = flattenedQuestions;

                global.ID = _quizData!['id'];
                global.currentUserProfile = _userProfile;
                global.creatorProfile = _creatorProfile;

                Navigator.pushNamed(context, "/Update Quiz");
              },
              enabled: hasPerm('can_update'),
              icon: Icons.edit_outlined,
            ),
            _buildRestrictedQuizAction(
              text: "Delete Quiz",
              onPressed: () async {
                try {
                  await DatabaseService().deleteDatabase(
                    docId: _quizData!['id'],
                    currentUserId: _user!.uid,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Quiz moved to trash (Soft Delete)"),
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Delete Error: $e")));
                  }
                }
              },
              enabled: hasPerm('can_delete'),
              icon: Icons.delete_outline,
            ),
          ],
        ],
      ],
    );
  }
}

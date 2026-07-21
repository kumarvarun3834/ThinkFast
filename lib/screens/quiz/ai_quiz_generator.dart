import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/ai_service.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AiQuizGenerator extends StatefulWidget {
  final bool forEditor;

  const AiQuizGenerator({super.key, this.forEditor = false});

  @override
  _AiQuizGeneratorState createState() => _AiQuizGeneratorState();
}

class _AiQuizGeneratorState extends State<AiQuizGenerator> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, dynamic> _quizSettings = {};
  final Map<String, dynamic> _profileUpdates = {};

  bool _isLoading = false;
  String _generationStatus =
      "Queued"; // Queued, Generating, Validating, Saving, Completed
  int _currentStep = 0;
  bool _updateProfileOnFirebase = false;
  Map<String, dynamic> _examConfigs = {};

  late List<Map<String, dynamic>> _steps;
  final List<String> _typingMessages = [
    "Analyzing your requirements...",
    "Brainstorming question patterns...",
    "Checking curriculum alignment...",
    "Optimizing difficulty curves...",
    "Finalizing your personalized quiz...",
  ];
  int _typingMessageIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _fetchExamConfigs();
    _steps = [
      {
        'id': 'goal',
        'question': 'What are you preparing for today?',
        'type': 'choice',
        'options': [
          '📚 School',
          '🎓 College',
          '🏆 Competitive Exam',
          '💼 Placement / Interview',
          '🧠 General Learning',
          '✍ Custom',
        ],
        'phase': 1,
      },
      {
        'id': 'exam',
        'question': 'Which exam are you targeting?',
        'type': 'choice',
        'options': [
          'JEE',
          'NEET',
          'UPSC',
          'GATE',
          'CAT',
          'SSC',
          'Banking',
          'Other',
        ],
        'phase': 1,
        'depends_on': {'goal': '🏆 Competitive Exam'},
      },
      {
        'id': 'subject',
        'question': 'Which subject should I focus on?',
        'type': 'tag_search',
        'options': [
          'Physics',
          'Chemistry',
          'Mathematics',
          'Biology',
          'General Studies',
          'Computer Science',
          'English',
        ],
        'phase': 1,
      },
      {
        'id': 'topic',
        'question': 'Excellent. What specific topic should I cover?',
        'type': 'tag_search',
        'options': [],
        'phase': 1,
      },
      {
        'id': 'quiz_type',
        'question': 'What kind of quiz would you like?',
        'type': 'choice',
        'options': [
          'Revision Quiz',
          'Practice Quiz',
          'Mock Test',
          'Adaptive Quiz ⭐',
          'Weak Topics Quiz ⭐',
          'Previous Year Style',
          'Concept Builder',
        ],
        'phase': 2,
      },
      {
        'id': 'count',
        'question': 'How many questions do you need?',
        'type': 'choice',
        'options': ['5', '10', '20', '30', '50', 'Custom'],
        'phase': 2,
      },
      {
        'id': 'formats',
        'question': 'Preferred question formats?',
        'type': 'choice',
        'options': [
          'Single Choice',
          'Multiple Choice',
          'Integer',
          'Assertion & Reason',
          'Match the Following',
          'Mixed',
        ],
        'phase': 2,
      },
      {
        'id': 'difficulty',
        'question': 'Select the challenge level:',
        'type': 'choice',
        'options': ['Easy', 'Medium', 'Hard', 'Adaptive AI ⭐'],
        'phase': 2,
      },
      {
        'id': 'coverage',
        'question': 'How should AI generate this quiz?',
        'type': 'choice',
        'options': [
          'Entire Topic',
          'Important Concepts',
          'Frequently Asked Questions',
          'Previous Mistakes ⭐',
          'Exam-Oriented',
          'Mixed',
        ],
        'phase': 3,
      },
      {
        'id': 'personalization',
        'question':
            'I found your previous attempts. Should I personalize this quiz?',
        'type': 'choice',
        'options': [
          '✅ Focus on weak areas',
          '📈 Gradually increase difficulty',
          '🔄 Mix strong & weak topics',
          '❌ Ignore history',
        ],
        'phase': 3,
        'condition': () =>
            (global.currentUserProfile?['attemptCount'] ?? 0) > 0,
      },
      {
        'id': 'learning_objective',
        'question': "What's your primary goal?",
        'type': 'choice',
        'options': [
          'Revision',
          'Concept Building',
          'Speed Practice',
          'Accuracy',
          'Exam Simulation',
        ],
        'phase': 4,
      },
      {
        'id': 'time_limit',
        'question': 'Any time limit preferences?',
        'type': 'choice',
        'options': ['None', '10 min', '20 min', '30 min', 'Auto'],
        'phase': 4,
      },
      {
        'id': 'explanation_style',
        'question': 'Explanation Style:',
        'type': 'choice',
        'options': [
          'Detailed',
          'Concise',
          'Hints Only',
          'After Submission',
          'No Explanation',
        ],
        'phase': 4,
      },
    ];

    _addAiMessage(_steps[_currentStep]['question']);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTypingTimer() {
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _typingMessageIndex =
              (_typingMessageIndex + 1) % _typingMessages.length;
        });
      }
    });
  }

  void _addAiMessage(String text) {
    setState(() {
      _messages.add({'sender': 'ai', 'text': text});
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
    });
    _scrollToBottom();
  }

  Future<void> _fetchExamConfigs() async {
    final settings = SettingsService();
    try {
      final configs = await settings.getExamConfigs();
      if (mounted) {
        setState(() {
          _examConfigs = configs;
          // Update the exam_type options with fetched keys
          final List<String> fetchedExams = configs.keys.toList();
          final List<String> defaultExams = [
            'None / General',
            'JEE Main',
            'NEET',
            'UPSC',
            'Other',
          ];

          // Merge and remove duplicates, maintaining order where possible
          final Set<String> allExams = {...defaultExams, ...fetchedExams};

          // Find the exam_type step and update its options
          for (var step in _steps) {
            if (step['id'] == 'exam_type') {
              step['options'] = allExams.toList();
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching exam configs: $e");
    }
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleInput(String value) {
    if (value.trim().isEmpty) return;

    final step = _steps[_currentStep];

    // Privacy Guard for "starred ⭐" features
    if (value.contains("⭐")) {
      final bool hasPrivacyAccepted = global.currentUserProfile?['optInAiAnalysis'] == true;
      if (!hasPrivacyAccepted) {
        _showPrivacyRequirementDialog();
        return;
      }
    }

    if (step['id'] == 'count' && value != 'Custom') {
      final int? val = int.tryParse(value);
      if (val != null && (val < 1 || val > 50)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter a valid number between 1 and 50"),
          ),
        );
        return;
      }
    }

    _quizSettings[step['id']] = value;
    _addUserMessage(value);
    _inputController.clear();

    _nextStep();
  }

  void _showPrivacyRequirementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_rounded, color: Colors.purpleAccent),
            const SizedBox(width: 12),
            Text(
              "Personalization Only",
              style: GoogleFonts.poppins(
                color: global.valueColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "Advanced features like Adaptive Quizzes and Weak Topic focus require the AI & Personalization policy to be accepted in your profile.",
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: global.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/profile");
            },
            child: const Text(
              "GO TO PROFILE",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    _currentStep++;

    // Skip steps based on logic or pre-filled values
    while (_currentStep < _steps.length) {
      final step = _steps[_currentStep];
      final stepId = step['id'];

      // Dependency Check
      if (step.containsKey('depends_on')) {
        final dependsOn = step['depends_on'] as Map<String, dynamic>;
        bool skip = false;
        dependsOn.forEach((key, value) {
          if (_quizSettings[key] != value) skip = true;
        });
        if (skip) {
          _currentStep++;
          continue;
        }
      }

      // Condition Check
      if (step.containsKey('condition')) {
        final bool Function() condition = step['condition'] as bool Function();
        if (!condition()) {
          _currentStep++;
          continue;
        }
      }

      // Skip steps that already have a value
      if (_quizSettings.containsKey(stepId)) {
        _currentStep++;
        continue;
      }

      break;
    }

    if (_currentStep < _steps.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addAiMessage(_steps[_currentStep]['question']);
      });
    } else {
      _showAiSummary();
    }
  }

  void _showAiSummary() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _addAiMessage(
        "I've designed your personalized learning path. Here's the plan:",
      );
      setState(() {
        _messages.add({'sender': 'ai', 'type': 'ai_summary'});
      });
      _scrollToBottom();
    });
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _isLoading = true;
      _generationStatus = "Generating";
      _typingMessageIndex = 0;
    });
    _startTypingTimer();
    try {
      final String prompt =
          "Generate a quiz with high personalization using this conversational context: ${_quizSettings.toString()}";

      setState(() => _generationStatus = "Validating");

      final String? examTag = _quizSettings['exam'];
      final List<String> tags = [];
      if (_quizSettings['subject'] != null) {
        tags.add(_quizSettings['subject']);
      }
      if (_quizSettings['topic'] != null) {
        tags.add(_quizSettings['topic']);
      }

      final Map<String, dynamic> result = await AiService().createAiQuiz(
        userId: global.currentUserProfile?['uid'] ?? '',
        userName: global.currentUserProfile?['name'] ?? 'User',
        prompt: prompt,
        examTag: examTag,
        tags: tags.isEmpty ? null : tags,
        additionalConfig: _quizSettings,
      );

      final String quizId = result['quizId'];
      final String explanation = result['explanation'] ?? '';

      setState(() => _generationStatus = "Saving");

      // AI Generation Insight is handled by the backend server for security and consistency.
      // The backend saves the explanation to explanation/{userId}/gen/{quizId} automatically.

      if (_updateProfileOnFirebase) {
        await global.db.updateProtectedDetails(
          uid: global.currentUserProfile?['uid'] ?? '',
          details: {
            if (_quizSettings['goal'] != null) 'goal': _quizSettings['goal'],
            if (_quizSettings['exam'] != null)
              'targetExam': _quizSettings['exam'],
            ..._profileUpdates,
          },
        );
      }

      setState(() => _generationStatus = "Completed");
      _typingTimer?.cancel();

      if (mounted) {
        // If personalization is active, show the insight before navigating
        if (explanation.isNotEmpty && global.currentUserProfile?['optInAiAnalysis'] == true) {
          _addAiMessage("Generation complete! Here is why this quiz is a great fit for you:");
          setState(() {
            _messages.add({
              'sender': 'ai',
              'type': 'personalization_insight',
              'text': explanation,
            });
          });
          _scrollToBottom();
          
          // Give user a moment to read before navigating
          await Future.delayed(const Duration(seconds: 5));
        }

        if (mounted) {
          if (widget.forEditor) {
            Navigator.pop(context, quizId);
          } else {
            Navigator.pushReplacementNamed(
              context,
              '/Quiz Details',
              arguments: quizId,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating quiz: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int maxPhases = 4;
    int currentPhase = _currentStep < _steps.length
        ? (_steps[_currentStep]['phase'] ?? 1)
        : maxPhases;

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text(
              "Quiz Wiz",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 4,
                child: LinearProgressIndicator(
                  value: currentPhase / maxPhases,
                  backgroundColor: global.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    global.primaryAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg['type'] == 'profile_review') {
                  return _buildProfileReview();
                }
                if (msg['type'] == 'ai_summary') {
                  return _buildAiSummary();
                }
                if (msg['type'] == 'personalization_insight') {
                  return _buildPersonalizationInsight(msg['text']);
                }
                return _buildChatBubble(msg);
              },
            ),
          ),
          if (_currentStep < _steps.length && !_isLoading) _buildInputArea(),
          if (_isLoading)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                decoration: BoxDecoration(
                  color: global.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: global.primaryAccent,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _typingMessages[_typingMessageIndex],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Status: $_generationStatus",
                      style: GoogleFonts.poppins(
                        color: global.labelColor,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final isAi = msg['sender'] == 'ai';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAi)
            Container(
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: global.primaryAccent,
                child: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isAi ? global.cardColor : global.primaryAccent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isAi ? 0 : 20),
                  bottomRight: Radius.circular(isAi ? 20 : 0),
                ),
                border: isAi ? Border.all(color: global.borderColor) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                msg['text'] ?? '',
                style: GoogleFonts.poppins(
                  color: isAi ? global.valueColor : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (!isAi)
            Container(
              margin: const EdgeInsets.only(left: 8, bottom: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: global.borderColor,
                backgroundImage: global.currentUserProfile?['photoUrl'] != null
                    ? NetworkImage(global.currentUserProfile!['photoUrl'])
                    : null,
                child: global.currentUserProfile?['photoUrl'] == null
                    ? const Icon(
                        Icons.person,
                        size: 14,
                        color: global.labelColor,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSummary() {
    final fields = {
      '📚 Goal': _quizSettings['goal'] ?? 'Not set',
      '📖 Subject': _quizSettings['subject'] ?? 'Not set',
      '📌 Topic': _quizSettings['topic'] ?? 'Not set',
      '🧠 Quiz Type': _quizSettings['quiz_type'] ?? 'Practice',
      '📝 Questions': _quizSettings['count'] ?? '10',
      '🎯 Difficulty': _quizSettings['difficulty'] ?? 'Medium',
      '⏱ Time': _quizSettings['time_limit'] ?? 'Auto',
      '📚 Explanations': _quizSettings['explanation_style'] ?? 'Detailed',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: global.primaryAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: global.primaryAccent.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: global.primaryAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                "Quiz Blueprint",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: global.valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    "${e.key}: ",
                    style: GoogleFonts.poppins(
                      color: global.labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: global.borderColor, height: 32),
          Row(
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                color: global.primaryAccent,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Enable Personalization?",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: global.labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _updateProfileOnFirebase,
                onChanged: (v) => setState(() => _updateProfileOnFirebase = v),
                activeColor: global.primaryAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: global.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: Text(
                "GENERATE TUTOR SESSION",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationInsight(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: global.infoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: global.infoColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: global.infoColor, size: 20),
              const SizedBox(width: 12),
              Text(
                "Personalization Insight",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: global.infoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: global.valueColor,
              fontSize: 14,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileReview() {
    final profile = global.currentUserProfile ?? {};
    final fields = {
      'Class/Grade': profile['class'] ?? 'Not set',
      'Study Goal': profile['goal'] ?? 'Not set',
      'Interests': (profile['interests'] as List? ?? []).join(', '),
      'Preferred Language': profile['preferredLanguage'] ?? 'English',
      'Learning Style': profile['learningStyle'] ?? 'Visual (Default)',
      'Target Exam': profile['targetExam'] ?? 'Not set',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Profile Preferences",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: global.primaryAccent,
            ),
          ),
          const SizedBox(height: 12),
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${e.key}: ",
                    style: GoogleFonts.poppins(
                      color: global.labelColor,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.poppins(
                        color: global.valueColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: global.borderColor, height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Update profile with these session settings?",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: global.labelColor,
                  ),
                ),
              ),
              Switch(
                value: _updateProfileOnFirebase,
                onChanged: (v) => setState(() => _updateProfileOnFirebase = v),
                activeThumbColor: global.primaryAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: global.primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                "Generate Quiz",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSuggestions(Map<String, dynamic> step) {
    final query = _inputController.text.trim().toLowerCase();
    final List<String> standardOptions = List<String>.from(
      step['options'] ?? [],
    );

    // Logic: If we are searching for topics, try to search within the selected subject hierarchy
    Query queryRef = FirebaseFirestore.instance.collection('tags');

    if (step['id'] == 'topic' && _quizSettings['subject'] != null) {
      final String subject = _quizSettings['subject'].toString().toLowerCase();
      queryRef = FirebaseFirestore.instance
          .collection('tags')
          .doc(subject)
          .collection('sub_topics');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: queryRef
          .orderBy('lastUsed', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final Set<String> allSuggestions = {...standardOptions};

        if (snapshot.hasData) {
          final dbTags = snapshot.data!.docs.map((doc) => doc.id).toList();
          allSuggestions.addAll(dbTags);
        }

        final List<String> filteredSuggestions = allSuggestions
            .where((tag) {
              if (query.isEmpty) return standardOptions.contains(tag);
              return tag.toLowerCase().contains(query) &&
                  tag.toLowerCase() != query;
            })
            .take(8)
            .toList();

        if (filteredSuggestions.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredSuggestions.map((tag) {
            return InkWell(
              onTap: () {
                _inputController.text = tag;
                _handleInput(tag);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: global.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: global.primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    color: global.primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final step = _steps[_currentStep];
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final double safePadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        keyboardPadding > 0 ? 12 : (safePadding + 20),
      ),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: global.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child:
          (step['type'] == 'text' ||
              step['type'] == 'integer' ||
              step['type'] == 'tag_search')
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step['type'] == 'tag_search') ...[
                  _buildTagSuggestions(step),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: global.bgColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: global.borderColor),
                        ),
                        child: TextField(
                          controller: _inputController,
                          autofocus: true,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: step['type'] == 'integer'
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(
                            hintText: step['type'] == 'tag_search'
                                ? "Type a subject..."
                                : step['hint'],
                            hintStyle: GoogleFonts.poppins(
                              color: global.hintColor,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            if (step['type'] == 'tag_search') setState(() {});
                          },
                          onSubmitted: _handleInput,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _handleInput(_inputController.text),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: global.primaryAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : step['type'] == 'dropdown'
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: global.bgColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: global.borderColor),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: global.cardColor,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: global.primaryAccent,
                ),
                underline: const SizedBox(),
                hint: Text(
                  "Select an option",
                  style: GoogleFonts.poppins(
                    color: global.hintColor,
                    fontSize: 13,
                  ),
                ),
                items: List<String>.from(step['options']).map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _handleInput(val);
                },
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: List<String>.from(step['options']).map((opt) {
                final bool isDestructive =
                    opt == 'Generate Now' || opt == 'No limit';
                return InkWell(
                  onTap: () => _handleInput(opt),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? global.primaryAccent
                          : global.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDestructive
                            ? global.primaryAccent
                            : global.borderColor,
                      ),
                    ),
                    child: Text(
                      opt,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: isDestructive
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

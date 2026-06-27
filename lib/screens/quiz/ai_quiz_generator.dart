import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/ai_service.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AiQuizGenerator extends StatefulWidget {
  const AiQuizGenerator({super.key});

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
  String _generationStatus = "Queued"; // Queued, Generating, Validating, Saving, Completed
  int _currentStep = 0;
  bool _updateProfileOnFirebase = false;
  Map<String, dynamic> _examConfigs = {};

  late List<Map<String, dynamic>> _steps;

  @override
  void initState() {
    super.initState();
    _fetchExamConfigs();
    _steps = [
      {
        'id': 'exam_type',
        'question': 'Are you preparing for a specific competitive exam?',
        'type': 'dropdown',
        'options': ['None / General', 'JEE Main', 'NEET', 'UPSC', 'Other'],
      },
      {
        'id': 'topic',
        'question': 'What topic would you like to study today?',
        'type': 'text',
        'hint': 'e.g., Quantum Mechanics, World War II',
      },
      {
        'id': 'subtopics',
        'question': 'Great. Which specific areas should I focus on?',
        'type': 'text',
        'hint': 'e.g., Wave Functions, Schrödinger Equation (Optional)',
      },
      {
        'id': 'count',
        'question': 'How many questions would you like? (Recommended: 1-50)',
        'type': 'integer',
        'hint': 'Enter a number (e.g. 20)',
      },
      {
        'id': 'avoid',
        'question': 'Are there any topics I should avoid?',
        'type': 'text',
        'hint': 'e.g., History of the era (Optional)',
      },
      {
        'id': 'difficulty',
        'question': 'How challenging should the quiz be?',
        'type': 'choice',
        'options': ['Easy', 'Medium', 'Hard', 'Random'],
      },
      {
        'id': 'distractor_style',
        'question': 'What style of distractors (wrong answers) do you prefer?',
        'type': 'choice',
        'options': ['Plausible', 'Confusing', 'Tricky', 'Obvious'],
      },
      {
        'id': 'cognitive_level',
        'question': 'What cognitive level should we target?',
        'type': 'choice',
        'options': [
          'Recall',
          'Understanding',
          'Application',
          'Analysis',
          'Evaluation',
          'Creation',
        ],
      },
      {
        'id': 'skill_level',
        'question': 'What is your current skill level in this topic?',
        'type': 'choice',
        'options': ['Beginner', 'Intermediate', 'Advanced'],
      },
      {
        'id': 'type',
        'question': 'What type of questions do you prefer?',
        'type': 'choice',
        'options': ['Single Choice', 'Multiple Choice', 'Integer', 'Mixed'],
      },
      {
        'id': 'hints_explanations',
        'question': 'Would you like hints and explanations included?',
        'type': 'choice',
        'options': ['Both', 'None', 'Hints Only', 'Explanations Only'],
      },
      {
        'id': 'tone',
        'question': 'What should be the tone of the quiz?',
        'type': 'choice',
        'options': ['Professional', 'Casual', 'Encouraging', 'Strict'],
      },
      {
        'id': 'feedback_timing',
        'question': 'When would you like to see the feedback?',
        'type': 'choice',
        'options': ['Immediate', 'After Quiz'],
      },
      {
        'id': 'time_limit',
        'question': 'Should there be a time limit?',
        'type': 'choice',
        'options': ['No limit', '10 min', '20 min', '30 min'],
      },
      {
        'id': 'coverage',
        'question': 'What should this quiz focus on?',
        'type': 'choice',
        'options': [
          'Entire syllabus',
          'Selected topics',
          'Weak topics',
          'Revision only',
          'Mixed',
        ],
      },
      {
        'id': 'source',
        'question': 'Where should I source the questions from?',
        'type': 'choice',
        'options': [
          'Textbook style',
          'Competitive exam style',
          'Previous year pattern',
          'AI generated',
          'Mixed',
        ],
      },
      {
        'id': 'profile_difficulty',
        'question': 'Should I optimize the question difficulty based on your performance profile?',
        'type': 'choice',
        'options': ['Yes', 'No'],
      },
      {
        'id': 'mistakes_focus',
        'question':
            'Would you like to focus on topics you\'ve struggled with before?',
        'type': 'choice',
        'options': ['Yes', 'No'],
      },
      {
        'id': 'grade',
        'question': 'What is your current Class / Grade?',
        'type': 'dropdown',
        'options': ['8th', '9th', '10th', '11th', '12th', 'Undergraduate', 'Graduate'],
        'isProfile': true,
      },
      {
        'id': 'study_goal',
        'question': 'What is your primary study goal?',
        'type': 'text',
        'hint': 'e.g., Crack JEE, Learn for fun',
        'isProfile': true,
      },
      {
        'id': 'learning_style',
        'question': 'What is your preferred learning style?',
        'type': 'choice',
        'options': ['Visual', 'Auditory', 'Reading/Writing', 'Kinesthetic'],
        'isProfile': true,
      },
    ];

    _addAiMessage(_steps[_currentStep]['question']);
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

    if (step['id'] == 'count') {
      final int? val = int.tryParse(value);
      if (val == null || val < 1 || val > 50) {
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

  void _nextStep() {
    final currentStepId = _steps[_currentStep]['id'];

    if (currentStepId == 'exam_type') {
      final selectedExam = _quizSettings['exam_type'];
      if (_examConfigs.containsKey(selectedExam)) {
        final config = _examConfigs[selectedExam] as Map<String, dynamic>;
        // Auto-fill any matching fields from the exam config
        config.forEach((key, value) {
          _quizSettings[key] = value.toString();
        });
      }
    }

    _currentStep++;

    // Skip steps that already have a value (pre-filled by exam selection or profile)
    while (_currentStep < _steps.length &&
        _quizSettings.containsKey(_steps[_currentStep]['id'])) {
      _currentStep++;
    }

    if (_currentStep < _steps.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addAiMessage(_steps[_currentStep]['question']);
      });
    } else {
      _showProfileReview();
    }
  }

  void _showProfileReview() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _addAiMessage(
        "Almost done! I'll also use your profile preferences to personalize this quiz.",
      );
      setState(() {
        _messages.add({'sender': 'ai', 'type': 'profile_review'});
      });
      _scrollToBottom();
    });
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _isLoading = true;
      _generationStatus = "Generating";
    });
    try {
      final ai = global.aiConnect;
      
      // Deep Profile Analytics (Mocked for now, should come from AnalyticsService)
      final profileAnalytics = {
        'avgScore': '68%',
        'accuracyByTopic': {'Arrays': '42%', 'Recursion': '91%'},
        'timeSpentPerQ': '45s',
        'weakTopics': ['Dynamic Programming', 'Graph Theory'],
      };

      final Map<String, dynamic> finalConfig = {
        ..._quizSettings,
        'profile': global.currentUserProfile,
        'analytics': profileAnalytics,
      };

      final String prompt =
          "Generate a quiz with high personalization using this config: ${finalConfig.toString()}";

      setState(() => _generationStatus = "Validating");
      
      final String quizId = await ai.createAiQuiz(
        userId: global.currentUserProfile?['uid'] ?? '',
        userName: global.currentUserProfile?['name'] ?? 'User',
        prompt: prompt,
      );

      setState(() => _generationStatus = "Saving");

      if (_updateProfileOnFirebase) {
        await global.db.updateProtectedDetails(
          uid: global.currentUserProfile?['uid'] ?? '',
          details: _profileUpdates,
        );
      }

      setState(() => _generationStatus = "Completed");

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/Quiz Details',
          arguments: quizId,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error generating quiz: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "AI Quiz Wizard",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg['type'] == 'profile_review') {
                  return _buildProfileReview();
                }
                return _buildChatBubble(msg);
              },
            ),
          ),
          if (_currentStep < _steps.length && !_isLoading) _buildInputArea(),
          if (_isLoading)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: global.primaryAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Status: $_generationStatus...",
                      style: GoogleFonts.poppins(color: global.primaryAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Building your personalized learning experience",
                      style: GoogleFonts.poppins(color: global.labelColor, fontSize: 11),
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
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAi ? global.cardColor : global.primaryAccent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAi ? 0 : 16),
            bottomRight: Radius.circular(isAi ? 16 : 0),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          msg['text'] ?? '',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
        ),
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
                activeColor: global.primaryAccent,
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

  Widget _buildInputArea() {
    final step = _steps[_currentStep];
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final double safePadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        keyboardPadding > 0 ? 12 : (safePadding + 16),
      ),
      decoration: BoxDecoration(
        color: global.cardColor,
        border: Border(top: BorderSide(color: global.borderColor)),
      ),
      child: (step['type'] == 'text' || step['type'] == 'integer')
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    keyboardType: step['type'] == 'integer'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      hintText: step['hint'],
                      hintStyle: GoogleFonts.poppins(color: global.hintColor),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _handleInput,
                  ),
                ),
                IconButton(
                  onPressed: () => _handleInput(_inputController.text),
                  icon: const Icon(Icons.send, color: global.primaryAccent),
                ),
              ],
            )
          : step['type'] == 'dropdown'
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: global.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: global.borderColor),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: global.cardColor,
                    underline: const SizedBox(),
                    hint: Text("Select an option", style: GoogleFonts.poppins(color: global.hintColor)),
                    items: List<String>.from(step['options']).map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: GoogleFonts.poppins(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _handleInput(val);
                    },
                  ),
                )
              : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<String>.from(step['options']).map((opt) {
                return ActionChip(
                  label: Text(
                    opt,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: global.borderColor,
                  onPressed: () => _handleInput(opt),
                );
              }).toList(),
            ),
    );
  }
}

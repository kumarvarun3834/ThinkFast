import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/add_quiz_data.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

import '../utils/global.dart' as global;

class QuizPage extends StatefulWidget {
  String docId;

  QuizPage(this.docId, {super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  User? user;
  bool _isAdmin = false;
  bool _isAi = false;
  bool _importEnabled = false;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;

  String visibility = "private";
  bool allowMultipleAttempts = true;

  // Marking Scheme
  String markingType = "default";
  final TextEditingController _globalCorrectController = TextEditingController(text: "4");
  final TextEditingController _globalWrongController = TextEditingController(text: "-1");
  final TextEditingController _scCorrectController = TextEditingController(text: "4");
  final TextEditingController _scWrongController = TextEditingController(text: "-1");
  final TextEditingController _mcCorrectController = TextEditingController(text: "4");
  final TextEditingController _mcWrongController = TextEditingController(text: "-1");

  // Questions
  final List<Map<String, Object>> questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _timeController = TextEditingController();

    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) {
        setState(() => user = u);
        if (u != null) {
          _checkAdminStatus(u.uid);
        }
      }
    });

    if (widget.docId.isNotEmpty) {
      _fetchQuiz(widget.docId);
    } else {
      questions.add({});
    }

    _loadFeatureFlags();
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final flags = await SettingsService().getFeatureFlags();
      if (mounted) {
        setState(() {
          _importEnabled = flags?['enable_import'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAdminStatus(String uid) async {
    final db = DatabaseService();
    final isAdmin = await AdminService().isAdmin(uid);
    
    // Fetch profile if not already loaded to check for AI role
    Map<String, dynamic>? profile = global.currentUserProfile;
    if (profile == null) {
      profile = await db.getUserProfile(uid);
      global.currentUserProfile = profile;
    }
    
    final bool isAi = profile?['role'] == 'ai';

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isAi = isAi;
      });
    }
  }

  void _showImportDialog() {
    final TextEditingController importController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Import Quiz Data", style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Paste a JSON string or a direct link to a JSON file.",
              style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: importController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Enter JSON or URL...",
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final input = importController.text.trim();
              if (input.isNotEmpty) {
                Navigator.pop(context);
                _importQuizData(input);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  Future<void> _importQuizData(String input) async {
    try {
      String jsonContent = input;
      if (input.startsWith("http")) {
        final response = await http.get(Uri.parse(input));
        if (response.statusCode == 200) {
          jsonContent = response.body;
        } else {
          throw Exception("Failed to fetch data from link");
        }
      }

      final dynamic decoded = jsonDecode(jsonContent);
      final Map<String, dynamic> data = decoded is List ? {"data": decoded} : decoded;

      setState(() {
        if (data['title'] != null) _titleController.text = data['title'].toString();
        if (data['description'] != null) _descriptionController.text = data['description'].toString();
        if (data['time'] != null) {
          _timeController.text = (data['time'] is int) 
              ? (data['time'] ~/ 60).toString() 
              : (int.tryParse(data['time'].toString()) ?? 0 ~/ 60).toString();
        }
        
        if (data['markingScheme'] != null) {
          final scheme = data['markingScheme'] as Map;
          markingType = scheme['type'] ?? 'default';
          // Load other fields if necessary
        }

        final List<dynamic> rawData = (data['data'] ?? data['questions'] ?? []) as List;
        if (rawData.isNotEmpty) {
          questions.clear();
          for (var q in rawData) {
            // Support both internal format and external easy format
            if (q['Q'] != null) {
              // Internal pattern uid/type/Q/Opt
              final qInfo = q['Q'] as Map;
              final qText = qInfo['text'].toString();
              final List<dynamic> opts = q['Opt'] as List;
              final List<String> choiceTexts = opts.map((o) => (o as Map)['text'].toString()).toList();
              
              // Note: Importer usually won't have answer_keys unless it's a full export
              // If it's internal, we might not have 'answers' field directly in 'data'
              questions.add({
                "question": qText,
                "choices": choiceTexts,
                "answers": <String>[], // Answers need to be set manually or provided in 'answers'
                "type": q['type'] ?? 'Single Choice',
              });
            } else {
              // Easy format: { question, choices: [], answers: [], type }
              questions.add({
                "question": q['question']?.toString() ?? '',
                "choices": List<String>.from(q['choices'] ?? []),
                "answers": List<String>.from(q['answers'] ?? []),
                "type": q['type'] ?? 'Single Choice',
                "correct": q['correct'] ?? 4,
                "wrong": q['wrong'] ?? -1,
              });
            }
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data imported successfully")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Import error: $e")));
    }
  }

  Future<void> _fetchQuiz(String docId) async {
    try {
      final db = DatabaseService();
      final data = await db.readDatabase(docId);

      // Get current user ID for security check in getQuizAnswers
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not authenticated");

      // Fetch answers because readDatabase strips them
      final answersMap = await db.getQuizAnswers(docId, uid, from: 'quizform');

      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        visibility = data['visibility'] ?? 'private';
        allowMultipleAttempts = data['allowMultipleAttempts'] ?? true;
        _timeController.text = ((data['time'] ?? 0) ~/ 60).toString();

        // Load Marking Scheme
        final scheme = data['markingScheme'] as Map? ?? {};
        markingType = scheme['type'] ?? 'default';
        if (markingType == 'entire_quiz') {
          _globalCorrectController.text = (scheme['global']?['correct'] ?? 4).toString();
          _globalWrongController.text = (scheme['global']?['wrong'] ?? -1).toString();
        } else if (markingType == 'per_question_type') {
          final pqt = scheme['perQuestionType'] as Map? ?? {};
          _scCorrectController.text = (pqt['Single Choice']?['correct'] ?? 4).toString();
          _scWrongController.text = (pqt['Single Choice']?['wrong'] ?? -1).toString();
          _mcCorrectController.text = (pqt['Multiple Choice']?['correct'] ?? 4).toString();
          _mcWrongController.text = (pqt['Multiple Choice']?['wrong'] ?? -1).toString();
        }

        final Map<String, dynamic> pqScheme = (scheme['perQuestion'] as Map?)?.cast<String, dynamic>() ?? {};

        final List<dynamic> rawModules = data['modules'] as List? ?? [];
        final List<Map<String, Object>> transformed = [];

        for (var module in rawModules) {
          final String qSubject = module['subject'].toString();
          final List<dynamic> rawQuestions = module['questions'] as List? ?? [];

          for (var q in rawQuestions) {
            final qInfo = q['Q'] as Map;
            final qUid = qInfo['id'].toString();
            final qText = qInfo['text'].toString();

            // Load individual marking if it exists
            final qMarking = pqScheme[qUid] as Map? ?? {};
            final int qCorrect = qMarking['correct'] ?? 4;
            final int qWrong = qMarking['wrong'] ?? -1;

            final List<dynamic> opts = q['Opt'] as List;
            final List<String> choiceTexts = [];
            final List<String> correctTexts = [];

            final List<String> correctUids = answersMap[qUid] ?? [];

            for (var o in opts) {
              final oMap = o as Map;
              final oUid = oMap['id'].toString();
              final oText = oMap['text'].toString();
              choiceTexts.add(oText);
              if (correctUids.contains(oUid)) {
                correctTexts.add(oText);
              }
            }

            transformed.add({
              "subject": qSubject,
              "question": qText,
              "choices": choiceTexts,
              "answers": correctTexts,
              "type": q['type'] ?? 'Single Choice',
              "correct": qCorrect,
              "wrong": qWrong,
            });
          }
        }

        questions
          ..clear()
          ..addAll(transformed);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Load error: $e")));
    }
  }

  Widget _buildMarkingSchemeSection() {
    if (!_isAdmin && markingType == "default") {
      return const SizedBox.shrink(); // Hide for non-admins if it's already default
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Marking Scheme",
          style: GoogleFonts.poppins(
            color: const Color(0xFFE2E8F0),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: !_isAdmin,
          child: Opacity(
            opacity: _isAdmin ? 1.0 : 0.6,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF1E293B),
                  value: markingType,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  items: const [
                    DropdownMenuItem(value: "default", child: Text("Default (+4, -1)")),
                    DropdownMenuItem(value: "entire_quiz", child: Text("Custom Global")),
                    DropdownMenuItem(value: "per_question_type", child: Text("Per Question Type")),
                    DropdownMenuItem(value: "per_question", child: Text("Per Question")),
                  ],
                  onChanged: (v) => setState(() => markingType = v!),
                  decoration: const InputDecoration(labelText: "Scheme Type"),
                ),
                if (markingType == "entire_quiz") ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _globalCorrectController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE2E8F0)),
                          decoration: const InputDecoration(labelText: "Correct Score"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _globalWrongController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFE2E8F0)),
                          decoration: const InputDecoration(labelText: "Wrong Score"),
                        ),
                      ),
                    ],
                  ),
                ],
                if (markingType == "per_question_type") ...[
                  const SizedBox(height: 16),
                  _buildTypeMarkingRow("Single Choice", _scCorrectController, _scWrongController),
                  const SizedBox(height: 12),
                  _buildTypeMarkingRow("Multiple Choice", _mcCorrectController, _mcWrongController),
                ],
              ],
            ),
          ),
        ),
        if (!_isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              "Note: Only administrators can modify the marking scheme.",
              style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeMarkingRow(String type, TextEditingController correct, TextEditingController wrong) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: correct,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: const InputDecoration(labelText: "Correct"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: wrong,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFFE2E8F0)),
                  decoration: const InputDecoration(labelText: "Wrong"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addNewForm() => setState(() => questions.add({}));

  void _removeForm(int index) {
    if (questions.length > 1) {
      setState(() => questions.removeAt(index));
    }
  }

  void _updateFormData(int index, Map<String, Object> data) {
    setState(() => questions[index] = data);
  }

  Future<void> _saveQuiz() async {
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login required")));
      return;
    }

    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields required")));
      return;
    }

    final time = int.tryParse(_timeController.text.trim());
    if (time == null || time <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid time")));
      return;
    }

    for (int i = 0; i < questions.length; i++) {
      final qText = (questions[i]['question'] ?? '').toString().trim();
      final List answers = questions[i]['answers'] as List? ?? [];

      if (qText.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Question ${i + 1} is empty")));
        return;
      }

      if (answers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Question ${i + 1} needs at least one correct answer",
            ),
          ),
        );
        return;
      }
    }

    // Prepare Marking Scheme
    final Map<String, dynamic> markingScheme = {'type': markingType};
    if (markingType == 'entire_quiz') {
      markingScheme['global'] = {
        'correct': int.tryParse(_globalCorrectController.text) ?? 4,
        'wrong': int.tryParse(_globalWrongController.text) ?? -1,
      };
    } else if (markingType == 'per_question_type') {
      markingScheme['perQuestionType'] = {
        'Single Choice': {
          'correct': int.tryParse(_scCorrectController.text) ?? 4,
          'wrong': int.tryParse(_scWrongController.text) ?? -1,
        },
        'Multiple Choice': {
          'correct': int.tryParse(_mcCorrectController.text) ?? 4,
          'wrong': int.tryParse(_mcWrongController.text) ?? -1,
        },
      };
    }

    final db = DatabaseService();

    try {
      if (widget.docId.isEmpty) {
        final newId = await db.createDatabase(
          creatorId: user!.uid,
          user: user!.displayName ?? user!.uid ?? "",
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
          time: time,
          markingScheme: markingScheme,
          allowMultipleAttempts: allowMultipleAttempts,
        );
        setState(() {
          widget.docId = newId;
          global.ID = newId; // 🔑 Save to global for precise tracking
        });
      } else {
        await db.updateDatabase(
          docId: widget.docId,
          currentUserId: user!.uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
          time: time,
          markingScheme: markingScheme,
          allowMultipleAttempts: allowMultipleAttempts,
        );
        global.ID = widget.docId;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Quiz saved")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Quiz Editor",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_importEnabled && (_isAdmin || _isAi))
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: Color(0xFF3B82F6)),
              onPressed: _showImportDialog,
              tooltip: "Import Data",
            ),
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Color(0xFF3B82F6)),
            onPressed: _saveQuiz,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: SidebarMenu(user: user),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
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
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Color(0xFFE2E8F0)),
                decoration: const InputDecoration(labelText: "Quiz Title"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Color(0xFFE2E8F0)),
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _timeController,
                style: const TextStyle(color: Color(0xFFE2E8F0)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: "Timer (minutes)"),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E293B),
                value: visibility,
                style: const TextStyle(color: Color(0xFFE2E8F0)),
                items: const [
                  DropdownMenuItem(value: "public", child: Text("Public")),
                  DropdownMenuItem(value: "private", child: Text("Private")),
                ],
                onChanged: (v) => setState(() => visibility = v!),
                decoration: const InputDecoration(labelText: "Visibility"),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  "Allow Multiple Attempts",
                  style: TextStyle(color: Color(0xFFE2E8F0)),
                ),
                subtitle: const Text(
                  "If disabled, users can only take this quiz once",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                value: allowMultipleAttempts,
                activeColor: const Color(0xFF3B82F6),
                onChanged: (bool value) {
                  setState(() {
                    allowMultipleAttempts = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildMarkingSchemeSection(),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                itemBuilder: (context, index) => Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        QuizForm(
                          form_data_part: questions[index],
                          onChanged: (d) => _updateFormData(index, d),
                          showIndividualMarking: markingType == "per_question",
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _removeForm(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: _addNewForm,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

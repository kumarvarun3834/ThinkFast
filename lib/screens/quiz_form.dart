import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/add_quiz_data.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
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

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;

  String visibility = "private";

  // Questions
  final List<Map<String, Object>> questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _timeController = TextEditingController();

    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => user = u);
    });

    if (widget.docId.isNotEmpty) {
      _fetchQuiz(widget.docId);
    } else {
      questions.add({});
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
        _timeController.text = ((data['time'] ?? 0) ~/ 60).toString();

        final List<dynamic> rawQuestions = data['data'] as List;
        final List<Map<String, Object>> transformed = [];

        for (var q in rawQuestions) {
          final qInfo = q['Q'] as Map;
          final qUid = qInfo['id'].toString();
          final qText = qInfo['text'].toString();

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
            "question": qText,
            "choices": choiceTexts,
            "answers": correctTexts,
            "type": q['type'] ?? 'Single Choice',
          });
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

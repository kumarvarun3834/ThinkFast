import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinkfast/add_quiz_data.dart';
import 'package:thinkfast/widgets/drawer_data.dart';
import 'package:thinkfast/services/firebase_direct_commands.dart';

class QuizPage extends StatefulWidget {
  String docId;
  QuizPage(this.docId,{super.key});

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
      final data = await DatabaseService().readDatabase(docId);

      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        visibility = data['visibility'] ?? 'private';
        _timeController.text = ((data['time'] ?? 0) ~/ 60).toString();

        questions
          ..clear()
          ..addAll(
            (data['data'] as List)
                .map((e) => Map<String, Object>.from(e))
                .toList(),
          );
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Load error: $e")));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Login required")));
      return;
    }

    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _timeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("All fields required")));
      return;
    }

    final time = int.tryParse(_timeController.text.trim());
    if (time == null || time <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid time")));
      return;
    }

    for (int i = 0; i < questions.length; i++) {
      if ((questions[i]['question'] ?? '').toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Question ${i + 1} is empty")),
        );
        return;
      }
    }

    final db = DatabaseService();

    try {
      if (widget.docId.isEmpty) {
        widget.docId = await db.createDatabase(
          creatorId: user!.uid,
          user: user!.email ?? user!.phoneNumber ?? "",
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
          time: time,
        );
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
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Quiz saved")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Editor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveQuiz,
          ),
        ],
      ),
      drawer: Drawer(
        child: SidebarMenu(user: user),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _timeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
              const InputDecoration(labelText: "Timer (minutes)"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: visibility,
              items: const [
                DropdownMenuItem(value: "public", child: Text("Public")),
                DropdownMenuItem(value: "private", child: Text("Private")),
              ],
              onChanged: (v) => setState(() => visibility = v!),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) => Card(
                child: Column(
                  children: [
                    QuizForm(
                      form_data_part: questions[index],
                      onChanged: (d) => _updateFormData(index, d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeForm(index),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

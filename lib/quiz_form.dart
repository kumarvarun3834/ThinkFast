import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart'; // Your QuizForm widget
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/firebase_direct_commands.dart';
import 'package:thinkfast/google_sign_in_provider.dart';

class QuizPage extends StatefulWidget {
  String docId;
  QuizPage(this.docId,{super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  // Metadata
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _intController;
  String visibility = "private";

  // Questions
  final List<Map<String, Object>> questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _intController = TextEditingController();

    if (widget.docId != "") {
      // Case: Editing existing quiz
      _fetchQuiz(widget.docId);
    } else {
      // Case: New quiz
      questions.add({});
    }
    _setupGoogleSignIn();
  }

  Future<void> _fetchQuiz(String docId) async {
    final db = DatabaseService();
    try {
      final data = await db.readDatabase(docId);

      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        visibility = data['visibility'] ?? 'private';

        questions.clear();
        questions.addAll(
          (data['data'] as List<dynamic>? ?? [])
              .map((e) => Map<String, Object>.from(e as Map))
              .toList(),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading quiz: $e")),
      );
    }
  }

  Future<void> _setupGoogleSignIn() async {
    try {
      await _provider.initialize(
        serverClientId:
        "775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com",
      );

      GoogleSignInAccount? account =
      await _provider.instance.attemptLightweightAuthentication();

      account ??= await _provider.instance.authenticate();

      if (mounted) setState(() => _user = account);

      _provider.instance.authenticationEvents.listen((event) {
        if (!mounted) return;
        if (event is GoogleSignInAuthenticationEventSignIn) {
          setState(() => _user = event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          setState(() => _user = null);
        }
      });
    } catch (e) {
      debugPrint("Google Sign-In initialization error: $e");
    }
  }

  void _addNewForm() => setState(() => questions.add({}));

  void _removeForm(int index) {
    if (questions.length == 1) return; // Prevent empty list
    setState(() => questions.removeAt(index));
  }

  void _updateFormData(int index, Map<String, Object> data) {
    setState(() => questions[index] = data);
  }

  Future<void> _saveQuiz() async {
    // if (_user == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text("Please sign in first")),
      //   );
      //   return;
      // }
    // Validation first
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title cannot be empty")),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description cannot be empty")),
      );
      return;
    }
    if (_intController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Number field cannot be empty")),
      );
      return;
    }

    // Convert number safely
    final number = int.tryParse(_intController.text.trim());
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid number")),
      );
      return;
    }
    // Validate questions
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final question = (q["question"] ?? "").toString().trim();
      final choices = (q["choices"] as List).map((e) => e.toString().trim()).where((c) => c.isNotEmpty).toList();
      final answers = (q["answers"] as List).map((e) => e.toString().trim()).toList();

      if (question.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Question ${i + 1} cannot be empty")),
        );
        return;
      }
      if (choices.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Question ${i + 1} must have at least 2 choices")),
        );
        return;
      }
      if (answers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Question ${i + 1} must have at least 1 correct answer")),
        );
        return;
      }
    }
    final db = DatabaseService();
    try {
      if (widget.docId == "") {
        final docId = await db.createDatabase(
          user: _user?.email ?? "",
          title: _titleController.text,
          description: _descriptionController.text,
          visibility: visibility,
          data: questions,
          time: _intController.text
        );
        debugPrint("Database created with ID: $docId");
        widget.docId = docId;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Quiz saved successfully!")),
        );
      } else {
        await db.updateDatabase(
          docId: widget.docId,
          currentUser: _user?.email ?? "",
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          visibility: visibility,
          data: questions,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Quiz updated successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Error creating/updating database: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _saveQuiz,
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                    (_user?.photoUrl != null) ? NetworkImage(_user!.photoUrl!) : null,
                    child: (_user?.photoUrl == null)
                        ? const Icon(Icons.account_circle, size: 60, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (_user != null)
                        ? "Hi, ${_user!.displayName ?? _user!.email}"
                        : "Hi, Guest",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            SidebarMenu(
              googleSignIn: _provider.instance,
              user: _user,
              refreshParent: () async {
                final account =
                await _provider.instance.attemptLightweightAuthentication();
                if (mounted) setState(() => _user = account);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),

            TextField(
              controller: _intController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Timer to set for quiz (in minutes)",
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // allows only integers
              ],
            ),

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: visibility,
              decoration: const InputDecoration(
                labelText: "Visibility",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "public", child: Text("Public")),
                DropdownMenuItem(value: "private", child: Text("Private")),
              ],
              onChanged: (value) {
                if (value != null) {
                  visibility = value; // update variable
                }
              },
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      QuizForm(
                        form_data_part: questions[index],
                        onChanged: (data) => _updateFormData(index, data),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeForm(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
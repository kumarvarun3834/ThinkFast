import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart'; // your QuizForm widget
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/firebase_direct_commands.dart';

class QuizPage extends StatefulWidget {
  final Function(Widget) onStateChange;
  const QuizPage({super.key, required this.onStateChange});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  GoogleSignInAccount? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Metadata
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String visibility = "private";

  // Questions
  List<Map<String, Object>> questions = [];

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() => _user = account);
    });
    _googleSignIn.signInSilently();

    _titleController = TextEditingController();
    _descriptionController = TextEditingController();

    // start with one question
    questions.add({});
  }

  void _addNewForm() {
    setState(() => questions.add({}));
  }

  void _removeForm(int index) {
    setState(() => questions.removeAt(index));
  }

  void _updateFormData(int index, Map<String, Object> data) {
    setState(() => questions[index] = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text("Quiz Builder"),
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
              onPressed: () async {
                final db = DatabaseService();
                try {
                  String docId = await db.createDatabase(
                    user: _user!.email,
                    title: _titleController.text,
                    description: _descriptionController.text,
                    visibility: visibility,
                    data: questions,
                  );
                  print("Database created with ID: $docId");
                } catch (e) {
                  print("Error creating database: $e");
                }
              },
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
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
                    backgroundImage: (_user != null && _user!.photoUrl != null)
                        ? NetworkImage(_user!.photoUrl!)
                        : null,
                    child: (_user == null || _user!.photoUrl == null)
                        ? const Icon(Icons.account_circle,
                        size: 60, color: Colors.white)
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
              googleSignIn: _googleSignIn,
              user: _user,
              onStateChange: widget.onStateChange,
              refreshParent: () => setState(() {}),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Visibility Dropdown
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(
                  labelText: "Visibility",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "private", child: Text("Private")),
                  DropdownMenuItem(value: "public", child: Text("Public")),
                ],
                onChanged: (val) => setState(() => visibility = val!),
              ),
              const SizedBox(height: 12),

              // Questions list
              Column(
                children: List.generate(questions.length, (index) {
                  return Card(
                    margin: const EdgeInsets.all(10),
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
                }),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

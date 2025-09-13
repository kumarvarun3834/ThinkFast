import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart'; // Your QuizForm widget
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/firebase_direct_commands.dart';
import 'package:thinkfast/google_sign_in_provider.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  // Metadata
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String visibility = "private";

  // Questions
  final List<Map<String, Object>> questions = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    questions.add({});
    _setupGoogleSignIn();
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
    try {
      final db = DatabaseService();
      final docId = await db.createDatabase(
        user: _user?.email ?? "",
        title: _titleController.text,
        description: _descriptionController.text,
        visibility: visibility,
        data: questions,
      );
      debugPrint("Database created with ID: $docId");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quiz saved successfully!")),
      );
    } catch (e) {
      debugPrint("Error creating database: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
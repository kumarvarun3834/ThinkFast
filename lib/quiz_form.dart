import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart'; // import your QuizForm widget
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/firebase_direct_commands.dart';

class QuizPage extends StatefulWidget {
  final Function(Widget) onStateChange;
  const QuizPage({super.key, required this.onStateChange});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Map<String, Object>> form_data = []; // ✅ only data
  GoogleSignInAccount? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String title="";
  String description="";
  String visibility="";

  void saveForm(
  TextEditingController questionController,
  List<TextEditingController> choiceControllers ,
  Set<int> selectedAnswers ,
  String? selectedValue
      ) {
  final question = questionController.text.trim();
  final choices = choiceControllers.map((c) => c.text.trim()).toList();
  final answers = selectedAnswers.map((i) => choices[i]).toList();
  print("Type: $selectedValue");
  print("Question: $question");
  print("choices: $choices");
  print("Correct Answers: $answers");
  Map<String,Object> form_data_part={
  "Type": ?selectedValue,
  "Question": question,
  "choices": choices,
  "answers":answers
  };
}

  void _addNewForm() {
    setState(() {
      form_data.add({}); // start empty data for new quiz form
    });
  }

  void _removeForm(int index) {
    setState(() {
      form_data.removeAt(index);
    });
  }

  void _updateFormData(int index, Map<String, Object> data) {
    setState(() {
      form_data[index] = data;
    });
  }


  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _user = account;
      });
    });
    _googleSignIn.signInSilently();

    // start with one form
    form_data.add({});
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
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
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
                print("📌 Final quiz data: $form_data");
                final DatabaseService dbService = DatabaseService();
                try {
                  String docId = await dbService.createDatabase(
                    user: _user!.email,
                    title: title,
                    description: description,
                    visibility: visibility,
                    data: form_data,
                  );
                  print("Database created with ID: $docId");
                } catch (e) {
                  print("Error creating database: $e");
                }
                // TODO: send to Firebase or save locally
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
                    style:
                    const TextStyle(color: Colors.white, fontSize: 18),
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
        child: Column(
          children: List.generate(form_data.length, (index) {
            return Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  QuizForm(
                    form_data_part: form_data[index],
                    onChanged: (data) => _updateFormData(index, data), saveForm:saveForm,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

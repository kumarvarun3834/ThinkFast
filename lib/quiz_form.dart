import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart';
import 'package:thinkfast/drawer_data.dart'; // import your QuizForm widget

class QuizPage extends StatefulWidget {
  final void Function(String) onStateChange;
    QuizPage({super.key,
      required this.onStateChange});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final List<QuizForm> _forms = [const QuizForm()];

  void _addNewForm() {
    setState(() {
      _forms.add(const QuizForm());
    });
  }

  void _removeForm(int index) {
    setState(() {
      _forms.removeAt(index);
    });
  }

  GoogleSignInAccount? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() {
        _user = account;
      });
    });
    _googleSignIn.signInSilently(); // restore last login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          titleSpacing: 0, // so title sits right after menu button
          title: const Text("Quiz Builder"),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer(); // open sidebar
              },
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // red button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {

                  // action here
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
                googleSignIn: _googleSignIn,
                user: _user,
                onStateChange: widget.onStateChange,
                refreshParent: () => setState(() {}), // refresh sidebar
              ),
            ],
          ),
        ),
      body: SingleChildScrollView(
        child: Column(
          children: List.generate(_forms.length, (index) {
            return Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _forms[index],
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

      // Add new form button

      ),

        floatingActionButton: FloatingActionButton(
          onPressed: _addNewForm,
          child: const Icon(Icons.add),
        )
    );

  }
}

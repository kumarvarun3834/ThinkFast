import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/add_quiz_data.dart'; // import your QuizForm widget

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

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
              if (_user==null)ListTile(
                leading: const Icon(Icons.login),
                title: const Text('login'),
                onTap: () async {
                  // Navigator.pop(context); // close sidebar
                  // widget.onStateChange("login");
                  try {
                    final account = await _googleSignIn.signIn();
                    if (account != null) {
                      setState(() {
                        _user = account;
                        // widget.onStateChange("Main_Screen");
                      });
                    }
                  } catch (error) {
                    print("Google login failed: $error");
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (_user!=null)ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: ()
                  // Navigator.pop(context);
                  async {
                    await _googleSignIn.signOut();
                    setState(() {
                      _user = null;
                      // widget.onStateChange("login");
                    });
                  }
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

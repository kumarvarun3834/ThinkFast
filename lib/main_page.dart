import 'package:flutter/material.dart';
import 'package:thinkfast/start_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class main_page extends StatefulWidget {
  final void Function(String) onStateChange;

  main_page({
    required this.onStateChange,
    super.key,
  });

  @override
  State<main_page> createState() => _main_page();
}

class _main_page extends State<main_page> {

  void switchToResultScreen() {
    widget.onStateChange("Quesation_Screen");
  }

  void switchState() {
    setState(() {
        switchToResultScreen();
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
      appBar: AppBar(title: const Text("Sidebar Example")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(
                (_user != null)
                    ? 'Hi, ${_user!.displayName ?? _user!.email}'
                    : "Login to load profile",
                style: const TextStyle(color: Colors.white, fontSize: 24),
    ),

    ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('login'),
              onTap: () {
                // Navigator.pop(context); // close sidebar
                widget.onStateChange("login");
                 },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: ()
                // Navigator.pop(context);
                async {
                  await _googleSignIn.signOut();
                  setState(() {
                    _user = null;
                    widget.onStateChange("login");
                  });
                }
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 36, 7, 156),
              Color.fromARGB(255, 8, 0, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Main_Screen(onPressed: switchState)
              ),
            ],
        )
      )
    );
  }
}


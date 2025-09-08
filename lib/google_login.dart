import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/main_page.dart';

class glogin extends StatefulWidget {
  final void Function(String) onStateChange;
  String currState;
  glogin({
    required this.onStateChange,
    required this.currState,
    super.key});

  @override
  State<StatefulWidget> createState() => _glogin();
}

class _glogin extends State<glogin> {
  GoogleSignInAccount? _user;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleGoogleLogin() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        setState(() {
          _user = account;
         widget.onStateChange("Main_Screen");
        });
      }
    } catch (error) {
      print("Google login failed: $error");
    }
  }

  void _logout() async {
    await _googleSignIn.signOut();
    setState(() {
      _user = null;
      widget.onStateChange("login");
    });
  }

  @override
  Widget build(context) {
    return Scaffold(
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
        child: Center(
          child: (widget.currState == "Main_Screen")
              ? main_page(onStateChange:widget.onStateChange ) // ✅ your quiz main screen
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _handleGoogleLogin,
                child: const Text("Login with Google"),
              ),
              if (_user != null) ...[
                const SizedBox(height: 20),
                Text("Email: ${_user!.email}", style: TextStyle(color: Colors.white)),
                Text("Name: ${_user!.displayName}", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _logout,
                  child: const Text("Logout"),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

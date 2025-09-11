import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/start_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class main_page extends StatefulWidget {
  final Function(Widget) onStateChange;

  const main_page({required this.onStateChange, super.key});

  @override
  State<main_page> createState() => _main_page();
}

class _main_page extends State<main_page> {
  GoogleSignInAccount? _user;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  /// Initialize Google Sign-In and listen to auth events
  Future<void> _initializeGoogleSignIn() async {
    try {
      // Attempt lightweight authentication (may show UI on some platforms)
      await _googleSignIn.attemptLightweightAuthentication();

      // Listen to auth state changes
      _googleSignIn.authenticationEvents.listen((account) {
        setState(() {
          _user = account as GoogleSignInAccount?;
        });
      });
    } catch (e) {
      print("Google Sign-In initialization error: $e");
    }
  }

  void switchState(String id) {
    List<Map<String, Object>> dataSet = [];
    setState(() {
      widget.onStateChange(
        Quesations(dataSet, onStateChange: widget.onStateChange),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: TextContainer("THINKFAST", Colors.black, 20)),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
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
              refreshParent: () => setState(() {}), // refresh sidebar
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Main_Screen(onPressed: widget.onStateChange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

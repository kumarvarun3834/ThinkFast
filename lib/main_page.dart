import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/start_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/google_sign_in_provider.dart'; // Make sure you have this provider set up

class MainPage extends StatefulWidget {
  final Function(Widget) onStateChange;

  const MainPage({required this.onStateChange, super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  @override
  void initState() {
    super.initState();
    _setupGoogleSignIn();
  }

  Future<void> _setupGoogleSignIn() async {
    try {
      // Initialize with serverClientId (mandatory for Android)
      await _provider.initialize(
        serverClientId:
        "775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com",
      );

      // Attempt silent/lightweight login
      GoogleSignInAccount? account =
      await _provider.instance.attemptLightweightAuthentication();

      // Fallback to interactive login if needed
      account ??= await _provider.instance.authenticate();

      // Set signed-in user
      setState(() {
        _user = account;
      });

      // Listen to authentication events
      _provider.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          setState(() => _user = event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          setState(() => _user = null);
        }
      });
    } catch (e) {
      print("Google Sign-In initialization error: $e");
    }
  }

  void switchState(String id) {
    List<Map<String, Object>> dataSet = [];
    widget.onStateChange(
      Quesations(dataSet, onStateChange: widget.onStateChange),
    );
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
                    backgroundImage: (_user?.photoUrl != null)
                        ? NetworkImage(_user!.photoUrl!)
                        : null,
                    child: (_user?.photoUrl == null)
                        ? const Icon(Icons.account_circle,
                        size: 60, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _user != null
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

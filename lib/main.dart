import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/ImageContainer.dart';
import 'package:thinkfast/google_sign_in_provider.dart';
import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/quiz_form.dart';
import 'package:thinkfast/result_screen.dart';
import 'package:thinkfast/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkFast',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MySplash(),
    );
  }
}

/// SPLASH SCREEN
class MySplash extends StatefulWidget {
  const MySplash({super.key});

  @override
  State<MySplash> createState() => _MySplashState();
}

class _MySplashState extends State<MySplash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ImageContainer(
              "assets/images/quiz-logo.png",
              const Color.fromARGB(128, 255, 255, 255),
              350,
              300,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// MAIN HOME (with Google Sign-In + Navigator)
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() => _Quiz();
}

class _Quiz extends State<MyHomePage> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  late Widget _currState;
  Future<void> _setupGoogleSignIn() async {
    try {
      await _provider.initialize(
        serverClientId:
        "775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com",
      );

      GoogleSignInAccount? account =
      await _provider.instance.attemptLightweightAuthentication();

      account ??= await _provider.instance.authenticate();

      setState(() => _user = account);

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

  @override
  void initState() {
    super.initState();
    _setupGoogleSignIn();
  }

  /// Shuffle Quiz Data
  List<Map<String, Object>> shuffleQuizData(
      List<Map<String, Object>> quizData) {
    for (var item in quizData) {
      (item["options"] as List<String>).shuffle();
    }
    quizData.shuffle();
    return quizData;
  }

  /// State Change Helper
  Widget _wrapWithGradient(Widget child) {
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
        child: child,
      ),
    );
  }


  /// Navigator Routes
  @override
  Widget build(BuildContext context) {
    return Navigator(
      initialRoute: '/home',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
              builder: (context) =>
                  _wrapWithGradient(Main_Screen(visibility: false)),
            );
          case '/My Quiz':
            return MaterialPageRoute(
              builder: (context) => _wrapWithGradient(
                Main_Screen(visibility: true, creatorId: _user),
              ),
            );
          case '/Create Quiz':
            return MaterialPageRoute(
              builder: (context) => _wrapWithGradient(QuizPage("")),
            );
          case '/Quiz':
            return MaterialPageRoute(
              builder: (context) => const Quesations(),
            );
          case '/Quiz Result':
            return MaterialPageRoute(
              builder: (context) =>
                  _wrapWithGradient(ResultScreen()),
            );
          default:
            return MaterialPageRoute(
              builder: (context) =>
                  _wrapWithGradient(Main_Screen(visibility: false)),
            );
        }
      },
    );
  }
}

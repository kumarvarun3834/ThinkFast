import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:thinkfast/widgets/ImageContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:thinkfast/screens/quesations.dart';
import 'package:thinkfast/screens/quiz_form.dart';
import 'package:thinkfast/screens/result_screen.dart';
import 'package:thinkfast/screens/start_screen.dart';
import 'package:thinkfast/auth/login_screen.dart';
import 'package:thinkfast/auth/signup_screen.dart';
import 'package:thinkfast/auth/verification_screen.dart';

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
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/verify': (context) => const VerificationScreen(),
        '/home': (context) => const MyHomePage(),
      },
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
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
    // Note: We use the top-level Navigator defined in MaterialApp for auth routes.
    // This internal Navigator is used for sub-navigation if needed, 
    // but here it handles the main screen logic.
    return Navigator(
      initialRoute: '/home_content',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home_content':
            return MaterialPageRoute(
              builder: (context) => _wrapWithGradient(
                const Main_Screen(showMyQuizzes: false), // public quizzes
              ),
            );

          case '/My Quiz':
            return MaterialPageRoute(
              builder: (context) {
                final user = FirebaseAuth.instance.currentUser;
                return _wrapWithGradient(
                  Main_Screen(
                    showMyQuizzes: true,
                    creator: user, // 🔑 pass logged-in user
                  ),
                );
              },
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
              builder: (context) => _wrapWithGradient(ResultScreen()),
            );

          case '/Update Quiz':
            return MaterialPageRoute(
              builder: (context) => _wrapWithGradient(QuizPage(global.ID)),
            );

          default:
            return MaterialPageRoute(
              builder: (context) => _wrapWithGradient(
                const Main_Screen(showMyQuizzes: false),
              ),
            );
        }
      },
    );
  }
}

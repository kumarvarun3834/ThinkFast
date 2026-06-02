import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:thinkfast/screens/splash_screen.dart';
import 'package:thinkfast/screens/quesations.dart';
import 'package:thinkfast/screens/quiz_details_screen.dart';
import 'package:thinkfast/screens/quiz_form.dart';
import 'package:thinkfast/screens/start_screen.dart';
import 'package:thinkfast/screens/result_screen.dart';
import 'package:thinkfast/auth/login_screen.dart';
import 'package:thinkfast/auth/signup_screen.dart';
import 'package:thinkfast/auth/verification_screen.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/services/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize Google Sign In for Android
  await GoogleSignIn.instance.initialize(
    serverClientId: DefaultFirebaseOptions.serverClientId,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 🎨 Common Gradient Wrapper
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkFast',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MySplash(),
      onGenerateRoute: (settings) {
        Widget page;
        bool wrapInGradient = true;

        switch (settings.name) {
          case '/login':
            page = const LoginScreen();
            wrapInGradient = false;
            break;
          case '/signup':
            page = const SignupScreen();
            wrapInGradient = false;
            break;
          case '/verify':
            page = const VerificationScreen();
            wrapInGradient = false;
            break;
          case '/home':
            page = const Main_Screen(showMyQuizzes: false);
            wrapInGradient = false; // Main_Screen has its own gradient/Scaffold
            break;
          case '/My Quiz':
            page = Main_Screen(
              showMyQuizzes: true,
              creator: FirebaseAuth.instance.currentUser,
            );
            wrapInGradient = false;
            break;
          case '/Create Quiz':
            page = QuizPage("");
            wrapInGradient = false;
            break;
          case '/Update Quiz':
            page = QuizPage(global.ID);
            wrapInGradient = false;
            break;
          case '/Quiz':
            page = const Quesations();
            wrapInGradient = false;
            break;
          case '/Quiz Result':
            page = ResultScreen();
            wrapInGradient = true;
            break;
          case '/Quiz Details':
            page = QuizDetailsScreen(quizId: settings.arguments as String);
            wrapInGradient = false;
            break;
          default:
            page = const Main_Screen(showMyQuizzes: false);
            wrapInGradient = false;
            break;
        }

        return MaterialPageRoute(
          builder: (context) => wrapInGradient ? _wrapWithGradient(page) : page,
        );
      },
    );
  }
}

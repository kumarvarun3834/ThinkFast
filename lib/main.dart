import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:thinkfast/screens/splash_screen.dart';
import 'package:thinkfast/screens/quesations.dart';
import 'package:thinkfast/screens/quiz_details_screen.dart';
import 'package:thinkfast/screens/quiz_form.dart';
import 'package:thinkfast/screens/start_screen.dart';
import 'package:thinkfast/screens/result_screen.dart';
import 'package:thinkfast/screens/about_us.dart';
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

  /// 🎨 Common Background Wrapper
  Widget _wrapWithGradient(Widget child) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkFast',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
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
            page = const ResultScreen();
            wrapInGradient = false;
            break;
          case '/Quiz Details':
            page = QuizDetailsScreen(quizId: settings.arguments as String);
            wrapInGradient = false;
            break;
          case '/About Us':
            page = const AboutUsScreen();
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

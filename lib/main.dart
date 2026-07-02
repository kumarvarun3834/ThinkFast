import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/auth/login_screen.dart';
import 'package:thinkfast/auth/signup_screen.dart';
import 'package:thinkfast/auth/verification_screen.dart';
import 'package:thinkfast/screens/main_screen.dart';
import 'package:thinkfast/screens/admin/admin_panel.dart';
import 'package:thinkfast/screens/admin/manage_admins_screen.dart';
import 'package:thinkfast/screens/drawer/about_us.dart';
import 'package:thinkfast/screens/drawer/my_attempts_screen.dart';
import 'package:thinkfast/screens/moderation/ban_screen.dart';
import 'package:thinkfast/screens/moderation/maintenance_screen.dart';
import 'package:thinkfast/screens/moderation/quiz_moderation_screen.dart';
import 'package:thinkfast/screens/profile/profile_screen.dart';
import 'package:thinkfast/screens/quiz/ai_quiz_generator.dart';
import 'package:thinkfast/screens/quiz/questions.dart';
import 'package:thinkfast/screens/quiz/quiz_collaborators_screen.dart';
import 'package:thinkfast/screens/quiz/quiz_details_screen.dart';
import 'package:thinkfast/screens/quiz/quiz_form.dart';
import 'package:thinkfast/screens/quiz/quiz_responses_screen.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/screens/splash_screen.dart';
import 'package:thinkfast/services/firebase/firebase_options.dart';
import 'package:thinkfast/utils/global.dart' as global;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize AppLinks handling
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri);
  });

  // Handle initial link if app was closed
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    _handleDeepLink(initialUri);
  }

  // Initialize Google Sign In for Android
  await GoogleSignIn.instance.initialize(
    serverClientId: DefaultFirebaseOptions.serverClientId,
  );

  runApp(const MyApp());
}

void _handleDeepLink(Uri uri) {
  debugPrint("Deep Link Received: $uri");
  debugPrint("Path: ${uri.path}");

  if (uri.path.contains('/quiz')) {
    final quizId = uri.queryParameters['id'];
    if (quizId != null && quizId.isNotEmpty) {
      debugPrint("Navigating to Quiz: $quizId");

      // Delay slightly to ensure Navigator is mounted
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushNamed(
          '/Quiz Details',
          arguments: quizId,
        );
      });
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 🎨 Common Background Wrapper
  Widget _wrapWithGradient(Widget child) {
    return Scaffold(backgroundColor: global.bgColor, body: child);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ThinkFast',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: global.bgColor,
        primaryColor: global.btnColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: global.primaryAccent,
          brightness: Brightness.dark,
          surface: global.cardColor,
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
            page = const MainScreen(showMyQuizzes: false);
            wrapInGradient = false; // Main_Screen has its own gradient/Scaffold
            break;
          case '/My Quiz':
            page = MainScreen(
              showMyQuizzes: true,
              creator: FirebaseAuth.instance.currentUser,
            );
            wrapInGradient = false;
            break;
          case '/Managed Quizzes':
            page = MainScreen(showManagedQuizzes: true);
            wrapInGradient = false;
            break;
          case '/Recycle Bin':
            page = MainScreen(
              showTrash: true,
              creator: FirebaseAuth.instance.currentUser,
            );
            wrapInGradient = false;
            break;
          case '/Create Quiz':
            page = QuizPage("");
            wrapInGradient = false;
            break;
          case '/Update Quiz':
            page = QuizPage(global.id);
            wrapInGradient = false;
            break;
          case '/AI Quiz Generator':
            page = const AiQuizGenerator();
            wrapInGradient = false;
            break;
          case '/Quiz':
            page = const Questions();
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
          case '/My Attempts':
            page = MyAttemptsScreen(quizId: settings.arguments as String?);
            wrapInGradient = false;
            break;
          case '/About Us':
            page = const AboutUsScreen();
            wrapInGradient = false;
            break;
          case '/profile':
            page = const ProfileScreen();
            wrapInGradient = false;
            break;
          case '/Admin Panel':
            page = const AdminPanel();
            wrapInGradient = false;
            break;
          case '/Manage Admins':
            page = const ManageAdminsScreen();
            wrapInGradient = false;
            break;
          case '/Quiz Responses':
            final args = settings.arguments as Map<String, dynamic>;
            page = QuizResponsesScreen(
              quizId: args['quizId'],
              quizTitle: args['quizTitle'],
            );
            wrapInGradient = false;
            break;
          case '/Manage Collaborators':
            page = QuizCollaboratorsScreen(
              quizId: settings.arguments as String,
            );
            wrapInGradient = false;
            break;
          case '/Blocked Users':
            page = QuizModerationScreen(quizId: settings.arguments as String);
            wrapInGradient = false;
            break;
          case '/maintenance':
            page = const MaintenanceScreen();
            wrapInGradient = false;
            break;
          case '/banned':
            page = BanScreen(reason: settings.arguments as String?);
            wrapInGradient = false;
            break;
          default:
            page = const MainScreen(showMyQuizzes: false);
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

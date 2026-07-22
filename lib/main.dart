import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/auth/login_screen.dart';
import 'package:thinkfast/auth/signup_screen.dart';
import 'package:thinkfast/auth/verification_screen.dart';
import 'package:thinkfast/screens/drawer/privacy_policy.dart';
import 'package:thinkfast/screens/admin/admin_dashboard_screen.dart';
import 'package:thinkfast/screens/admin/manage_leaderboards_screen.dart';
import 'package:thinkfast/screens/notification_screen.dart';
import 'package:thinkfast/screens/Main_Screen.dart';
import 'package:thinkfast/screens/admin/admin_panel.dart';
import 'package:thinkfast/screens/admin/manage_admins_screen.dart';
import 'package:thinkfast/screens/drawer/about_us.dart';
import 'package:thinkfast/screens/drawer/settings_screen.dart';
import 'package:thinkfast/screens/drawer/my_attempts_screen.dart';
import 'package:thinkfast/screens/moderation/ban_screen.dart';
import 'package:thinkfast/screens/moderation/maintenance_screen.dart';
import 'package:thinkfast/screens/moderation/quiz_moderation_screen.dart';
import 'package:thinkfast/screens/profile/profile_screen.dart';
import 'package:thinkfast/screens/quiz/ai_generation_status_screen.dart';
import 'package:thinkfast/screens/quiz/ai_quiz_generator.dart';
import 'package:thinkfast/screens/quiz/leaderboard_screen.dart';
import 'package:thinkfast/screens/quiz/questions.dart';
import 'package:thinkfast/screens/quiz/quiz_collaborators_screen.dart';
import 'package:thinkfast/screens/quiz/quiz_details_screen.dart';
import 'package:thinkfast/screens/quiz/quiz_form.dart';
import 'package:thinkfast/screens/quiz/quiz_responses_screen.dart';
import 'package:thinkfast/screens/quiz/result_screen.dart';
import 'package:thinkfast/screens/splash_screen.dart';
import 'package:thinkfast/services/session_service.dart';
import 'package:thinkfast/services/firebase/firebase_options.dart';
import 'package:thinkfast/utils/global.dart' as global;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  if (kDebugMode) {
    // In debug mode, print the App Check token to help register it in Firebase Console
    FirebaseAppCheck.instance.getToken().then((token) {
      debugPrint("--- FIREBASE APP CHECK DEBUG TOKEN ---");
      debugPrint(token);
      debugPrint("---------------------------------------");
    }).catchError((e) {
      debugPrint("Failed to get App Check token: $e");
    });
  }

  // Initialize Firebase Performance
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(!kDebugMode);

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Start tracking single device login
    SessionService().startDeviceTracking();
  }

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
          case '/AI Generations':
            page = MainScreen(
              showAiGenerations: true,
              creator: FirebaseAuth.instance.currentUser,
            );
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
          case '/AI Generation Status':
            page = AiGenerationStatusScreen(initialQuizId: settings.arguments as String?);
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
          case '/Privacy Policy':
            page = const PrivacyPolicyScreen();
            wrapInGradient = false;
            break;
          case '/Notifications':
            page = const NotificationScreen();
            wrapInGradient = false;
            break;
          case '/profile':
            page = const ProfileScreen();
            wrapInGradient = false;
            break;
          case '/settings':
            page = const SettingsScreen();
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
          case '/dashboard':
            // Super Admin or Dashboard Permission Gate
            if (global.isAdmin && (global.adminLevel == 0 || global.adminPermissions.contains('access_dashboard'))) {
              page = const AdminDashboardScreen();
            } else {
              page = const MainScreen(showMyQuizzes: false);
            }
            wrapInGradient = false;
            break;
          case '/Manage Leaderboards':
            page = ManageLeaderboardsScreen(
              quizId: settings.arguments as String?,
            );
            wrapInGradient = false;
            break;
          case '/Leaderboard':
            final args = settings.arguments as Map<String, dynamic>;
            page = LeaderboardScreen(
              quizId: args['quizId'],
              quizTitle: args['quizTitle'],
            );
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

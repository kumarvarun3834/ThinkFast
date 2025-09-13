import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/google_sign_in_provider.dart';
import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/quiz_form.dart';
import 'package:thinkfast/start_screen.dart';

class My_App extends StatelessWidget {
  const My_App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _Quiz();
  }
}

class _Quiz extends State<MyHomePage> {
  late String currState; //late keyword is used to tell dart i will initialize it later
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();
  // List<Map<String, Object>> quizResult = [];
  // List<Map<String, Object>> quizData = [];

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
    // initializing currstate here
    super.initState();
    // setCurrState(Main_Screen());
    _setupGoogleSignIn();
  }

  List<Map<String, Object>> shuffleQuizData(List<Map<String, Object>> quizData) {
    for (var item in quizData) {
      (item["options"] as List<String>).shuffle();
    }
    quizData.shuffle();
    return quizData;
  }

  late Widget _currState;

  Widget setCurrState(Widget newState) {
    setState(() {
      _currState = Scaffold(body: Container(
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
          child:newState
      ),
      );
    });
    print("Changed to: $newState");
    return newState;
  }

  @override
  Widget build(context) {

    return MaterialApp(
        title: 'Named Routes Demo',
        // Start the app with the "/" named route. In this case, the app starts
        // on the FirstScreen widget.
        initialRoute: '/',
        routes: {
          // When navigating to the "/" route, build the FirstScreen widget.
          '/home': (context) => setCurrState(Main_Screen(visibility: false,)),
          '/My Quiz': (context) => setCurrState(Main_Screen(visibility: true,creatorId: _user,)),
          '/Create Quiz': (context) =>setCurrState(QuizPage()),
          "/Quiz": (context) => Quesations(),
        },
    );
  }
}


import 'package:flutter/material.dart';
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

  // List<Map<String, Object>> quizResult = [];
  // List<Map<String, Object>> quizData = [];

  @override
  void initState() {
    // initializing currstate here
    super.initState();
    setCurrState(Main_Screen(
      onPressed:setCurrState));
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
          '/': (context) => _currState,
          // When navigating to the "/second" route, build the SecondScreen widget.
          '/My Quiz': (context) => _currState,
          '/Create Quiz': (context) => _currState,
        },
    );
  }
}


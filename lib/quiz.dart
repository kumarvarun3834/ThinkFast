import 'package:flutter/material.dart';
import 'package:thinkfast/main_page.dart';
// import 'package:thinkfast/quesations.dart';
// import 'package:thinkfast/quiz_form.dart';
// import 'package:thinkfast/result_screen.dart';

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

  List<Map<String, Object>> quizResult = [];
  List<Map<String, Object>> quizData = [];

  @override
  void initState() {
    // initializing currstate here
    super.initState();
    setCurrState(main_page(onStateChange: setCurrState));
    // quizData = quizdatareset();
    // quizData = shuffleQuizData(quizData);
    // quizResult = quizReset(quizData);
    //
    // currState = "Main_Screen";
  }

  List<Map<String, Object>> shuffleQuizData(List<Map<String, Object>> quizData) {
    for (var item in quizData) {
      (item["options"] as List<String>).shuffle();
    }
    quizData.shuffle();
    return quizData;
  }

  // List<Map<String, Object>> quizdatareset() {
  //   return [
  //     {
  //       "question": "What are the main building blocks of Flutter UIs?",
  //       "answer": ["Widgets"],
  //       "options": [
  //         "Components",
  //         "Blocks",
  //         "Functions",
  //         "Widgets"
  //       ]
  //     },
  //     {
  //       "question": "How are Flutter UIs built?",
  //       "answer": ["By combining widgets in code"],
  //       "options": [
  //         "By combining widgets in a visual editor",
  //         "By defining widgets in config files",
  //         "By using XCode for iOS and Android Studio for Android",
  //         "By combining widgets in code"
  //       ]
  //     },
  //     {
  //       "question": "What's the purpose of a StatefulWidget?",
  //       "answer": ["Update UI as data changes"],
  //       "options": [
  //         "Update data as UI changes",
  //         "Ignore data changes",
  //         "Render UI that does not depend on data",
  //         "Update UI as data changes"
  //       ]
  //     },
  //     {
  //       "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
  //       "answer": ["StatelessWidget"],
  //       "options": [
  //         "StatefulWidget",
  //         "Both are equally good",
  //         "None of the above",
  //         "StatelessWidget"
  //       ]
  //     },
  //     {
  //       "question": "What happens if you change data in a StatelessWidget?",
  //       "answer": ["The UI is not updated"],
  //       "options": [
  //         "The UI is updated",
  //         "The closest StatefulWidget is updated",
  //         "Any nested StatefulWidgets are updated",
  //         "The UI is not updated"
  //       ]
  //     },
  //     {
  //       "question": "How should you update data inside of StatefulWidgets?",
  //       "answer": ["By calling setState()"],
  //       "options": [
  //         "By calling updateData()",
  //         "By calling updateUI()",
  //         "By calling updateState()",
  //         "By calling setState()"
  //       ]
  //     }
  //   ];
  // }

  // List<Map<String, Object>> quizReset(List<Map<String, Object>> quizData) {
  //   List<Map<String, Object>> quizResult = [];
  //   int x = 0;
  //   while (x <= quizData.length) {
  //     //             [Q, ans, false,  selected,trials]
  //     quizResult.add({
  //       "question": "a",
  //       "answer": "",
  //       "trials": 0,
  //       "selection": []
  //     });
  //     x++;
  //   }
  //   print("quiz reset");
  //   return quizResult;
  // }

  Widget? _currState;

  Widget setCurrState(Widget newState) {
    setState(() {
      _currState = newState;
    });
    print("Changed to: $newState");
    return newState;
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: _currState ?? const Center(child: Text("No screen yet")),
  //   );
  // }

  @override
  Widget build(context) {

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
          child:_currState
          
          // (currState == "Main_Screen")
          //     ? main_page(onStateChange: setCurrState,) :
          // (currState=="QuizForm")
          //     ?QuizPage(onStateChange: setCurrState,):
          // (currState == "Quesation_Screen")
          //     ? Quesations(quizData, quizResult,onStateChange: setCurrState)
          //     : ResultScreen(quizData,quizResult,onStateChange: setCurrState)
      ),
    );
  }
}


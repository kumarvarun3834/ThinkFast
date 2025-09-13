import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/global.dart' as global;

class Quesations extends StatefulWidget {
  const Quesations({super.key});

  @override
  State<Quesations> createState() => _Quesations();
}

class _Quesations extends State<Quesations> {
  int i = 0;
  Map<String, Object> currentData = {};

  void _shuffleQuestionsAndOptions() {
    final random = Random();
    global.quizData.shuffle(random);

    for (var q in global.quizData) {
      final opts = (q["options"] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      opts.shuffle(random);
      q["options"] = opts;
    }
  }

  @override
  void initState() {
    super.initState();
    _shuffleQuestionsAndOptions();
    global.quizResult = _quizReset(global.quizData);
    currentData = global.quizData[i];
    global.quizResult[i]["question"] = global.quizData[i]["question"].toString();
  }

  List<Map<String, Object>> _quizReset(List<Map<String, Object>> quizData) {
    List<Map<String, Object>> quizResult = [];
    for (int x = 0; x < quizData.length; x++) {
      quizResult.add({
        "question": quizData[x]["question"]?.toString() ?? "",
        "selection": <String>[],
        "visited": false,
      });
    }
    return quizResult;
  }

  void switchToResultScreen() {
    Navigator.popAndPushNamed(context, "/Quiz Result");
  }

  void switchState() {
    setState(() {
      currentData = global.quizData[i];
      global.quizResult[i]["question"] = global.quizData[i]["question"].toString();
      global.quizResult[i]["answer"] = global.quizData[i]["answer"]?.toString() ?? "";
    });
  }

  List<Widget> buttons_Data(Map<String, Object> quizData) {
    List<Widget> database = [];
    List<String> options = (quizData["choices"] as List<dynamic>)
        .map((e) => e.toString())
        .toList();

    for (var option in options) {
      database.add(
        buttons_opt(option, switchState, global.quizResult[i]),
      );
    }
    return database;
  }


  List<Widget> menu_opt() {
    return [
      for (int j = 0; j < global.quizData.length; j++)
        GestureDetector(
          onTap: () {
            i = j;
            switchState();
          },
          child: Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getQuestionColor(global.quizResult[j]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "${j + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Color _getQuestionColor(Map<String, Object> question) {
    final selection = (question["selection"] as List?) ?? [];
    if (selection.isEmpty) return Colors.grey; // not visited
    return selection.isNotEmpty ? Colors.green : Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom AppBar',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text("Quiz name"),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: switchToResultScreen,
                child: const Text(
                  "SUBMIT",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'Questions',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: menu_opt(),
                  ),
                ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  width: double.infinity,
                  child: Card(
                    color: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Question: ${currentData["question"]?.toString() ?? ""}",
                        style: GoogleFonts.poppins(
                          color: const Color.fromARGB(255, 0, 255, 255),
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.all(20),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Column(children: buttons_Data(currentData)),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: i > 0
                          ? () {
                        i--;
                        switchState();
                      }
                          : null,
                      child: TextContainer("PREVIOUS", Colors.black, 18),
                    ),
                    ElevatedButton(
                      onPressed: i < global.quizData.length - 1
                          ? () {
                        i++;
                        switchState();
                      }
                          : null,
                      child: TextContainer("NEXT", Colors.black, 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class buttons_opt extends StatelessWidget {
  final VoidCallback onPressed;
  final String opt;
  Map<String, Object> quizResult;
  Color colour = Colors.black;

  buttons_opt(this.opt, this.onPressed, this.quizResult, {super.key});

  @override
  Widget build(BuildContext context) {
    (quizResult["selection"] as List).cast<String>().contains(opt)
        ?colour=Colors.lightGreenAccent:colour=Colors.black;

    return Container(
        width: 350,
        child: OutlinedButton.icon(
            onPressed: () {
              List<String> selectionList = (quizResult["selection"] as List).cast<String>();
              if (!selectionList.contains(opt)) {
                selectionList.add(opt);
              } else {
                selectionList.remove(opt);
                print("$opt already exists");
              }
              print(quizResult);
              onPressed();
            },
            style: OutlinedButton.styleFrom(

              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              backgroundColor: Colors.white10,
              foregroundColor: colour,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            label: TextContainer(opt, colour, 20)
        )
    );
  }
}

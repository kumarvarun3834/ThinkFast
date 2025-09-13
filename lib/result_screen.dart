import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/global.dart' as global;

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> resultData = [];
    print(global.quizResult);
    int total_marks = 0;

    // Calculate total marks
    for (int i = 0; i < global.quizResult.length; i++) {
      List<String> selections =
          (global.quizResult[i]["selection"] as List?)?.cast<String>() ?? [];
      List<String> answers =
          (global.quizData[i]["answer"] as List?)?.cast<String>() ?? [];

      bool correct = selections.isNotEmpty &&
          selections.every((s) => answers.contains(s)) &&
          answers.every((a) => selections.contains(a));

      total_marks += correct ? 4 : -1;
    }

    // Marks panel
    resultData.add(Container(
      alignment: Alignment.center,
      height: 400,
      child: MarksPanel(
        totalCorrectAnswers: total_marks,
        totalQuestions: global.quizResult.length * 3,
      ),
    ));

    // Restart button
    resultData.add(Container(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, "/home");
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Icon(Icons.lock_reset_outlined),
        label: TextContainer("Restart Quiz", Colors.black, 30),
      ),
    ));

    // Detailed per-question result
    for (int i = 0; i < global.quizResult.length; i++) {
      Map<String, Object> resultDataset = global.quizResult[i];
      Map<String, Object> data = global.quizData[i];

      List<String> selections =
          (resultDataset["selection"] as List?)?.cast<String>() ?? [];
      List<String> answers =
          (data["answer"] as List?)?.cast<String>() ?? [];

      List<Widget> selectionWidgets = [];
      for (int y = 0; y < selections.length; y++) {
        selectionWidgets.add(TextContainer(
            "Selection ${y + 1}:",
            answers.contains(selections[y]) ? Colors.green : Colors.red,
            15));
        selectionWidgets.add(TextContainer(selections[y], Colors.white, 15));
      }

      int marksObtained = (answers.length == selections.length &&
          selections.every((s) => answers.contains(s)))
          ? 4
          : -1;

      resultData.add(Container(
        margin: const EdgeInsets.all(20),
        width: double.infinity,
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.15,
                color: Colors.blueGrey[700],
                child: Center(
                  child: TextContainer(
                    (i + 1).toString(),
                    Colors.white70,
                    20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.7,
                color: Colors.blueGrey[700],
                padding: EdgeInsets.all(9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextContainer("Question: ", Colors.white70, 20,
                        fontWeight: FontWeight.bold),
                    TextContainer(resultDataset["question"] as String? ?? "",
                        Colors.white70, 15),
                    TextContainer("Marks Obtained: ", Colors.white70, 18,
                        fontWeight: FontWeight.bold),
                    TextContainer("$marksObtained", Colors.white, 15),
                    TextContainer("Choices Record: ", Colors.white, 15),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: selectionWidgets,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    resultData.add(const SizedBox(height: 150));

    return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: resultData,
        ));
  }
}

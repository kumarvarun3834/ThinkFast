import 'package:flutter/material.dart';
import 'package:thinkfast/widgets/TextContainer.dart';
import 'package:thinkfast/utils/global.dart' as global;

class ResultScreen extends StatelessWidget {
  ResultScreen({super.key});
  int totalMarks = 0;
  int calculateTotalMarks() {
    int total = 0; // local accumulator
    for (int i = 0; i < global.quizResult.length; i++) {
      Map<String, Object> resultDataset = global.quizResult[i];
      Map<String, Object> data = global.quizData[i];

      List<String> selections =
          (resultDataset["selection"] as List?)?.cast<String>() ?? [];
      List<String> answers =
          (data["answers"] as List?)?.cast<String>() ?? [];

      int marksObtained = 0;
      if (selections.isEmpty) {
        marksObtained = 0; // no selection
      } else if (selections.length == answers.length &&
          selections.every((s) => answers.contains(s))) {
        marksObtained = 4; // all correct
      } else {
        marksObtained = -1; // wrong
      }

      total += marksObtained; // accumulate marks
    }
    return total; // return after loop
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> resultData = [];
    print(global.quizResult);
    print(global.quizData);
    totalMarks=calculateTotalMarks();
    // Marks panel
    resultData.add(Container(
      alignment: Alignment.center,
      height: 400,
      margin: const EdgeInsets.all(20),
      child: Card(
        color: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: MarksPanel(
              totalCorrectAnswers: totalMarks,
              totalQuestions: global.quizResult.length * 4
          ),
        ),
      ),
    ));

    // Restart button
    resultData.add(Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 20),
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
        icon: const Icon(Icons.lock_reset_outlined),
        label: TextContainer("Mani Menu", Colors.black, 30),
      ),
    ));

    // Detailed per-question result
    for (int i = 0; i < global.quizResult.length; i++) {
      Map<String, Object> resultDataset = global.quizResult[i];
      Map<String, Object> data = global.quizData[i];
      //
      List<String> selections =
          (resultDataset["selection"] as List?)?.cast<String>() ?? [];
      List<String> answers =
          (data["answers"] as List?)?.cast<String>() ?? [];
      //
      int marksObtained = 0;
      if (selections.isEmpty) {
        marksObtained = 0; // no selection
      } else if (selections.length == answers.length &&
          selections.every((s) => answers.contains(s))) {
        marksObtained = 4; // all correct
      } else {
        marksObtained = -1; // wrong
      }
      // totalMarks += marksObtained;


      List<Widget> correctAnswerWidgets = [
        TextContainer("Correct Answer(s):", Colors.white, 15, fontWeight: FontWeight.bold)
      ];
      for (var ans in answers) {
        correctAnswerWidgets.add(TextContainer(ans, Colors.green, 15));
      }

      List<Widget> selectionWidgets = [
        TextContainer("Your Selection(s):", Colors.white, 15, fontWeight: FontWeight.bold)
      ];
      for (var sel in selections) {
        bool isCorrect = answers.contains(sel);
        selectionWidgets.add(TextContainer(sel, isCorrect ? Colors.green : Colors.red, 15));
      }

      resultData.add(Container(
        margin: const EdgeInsets.all(20),
        width: double.infinity,
        child: Card(
          color: Colors.blueGrey[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextContainer("Q${i + 1}: ${resultDataset["question"] as String? ?? ""}",
                    Colors.white70, 18, fontWeight: FontWeight.bold),
                const SizedBox(height: 5),
                TextContainer("Marks Obtained: $marksObtained", Colors.white, 16),
                const SizedBox(height: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: correctAnswerWidgets,
                ),
                const SizedBox(height: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: selectionWidgets,
                ),
              ],
            ),
          ),
        ),
      ));
    }
    resultData.add(const SizedBox(height: 50));
    print(totalMarks);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: resultData,
      ),
    );
  }
}

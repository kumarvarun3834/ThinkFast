import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      List<String> answers = (data["answers"] as List?)?.cast<String>() ?? [];

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
    totalMarks = calculateTotalMarks();

    // Marks panel
    resultData.add(
      Container(
        alignment: Alignment.center,
        height: 400,
        margin: const EdgeInsets.all(20),
        child: Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          child: Center(
            child: MarksPanel(
              totalCorrectAnswers: totalMarks,
              totalQuestions: global.quizResult.length * 4,
            ),
          ),
        ),
      ),
    );

    // Restart button
    resultData.add(
      Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, "/home");
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE2E8F0),
            side: const BorderSide(color: Color(0xFF334155)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.home_outlined, color: Color(0xFF3B82F6)),
          label: Text(
            "Main Menu",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    // Detailed per-question result
    for (int i = 0; i < global.quizResult.length; i++) {
      Map<String, Object> resultDataset = global.quizResult[i];
      Map<String, Object> data = global.quizData[i];

      List<String> selections =
          (resultDataset["selection"] as List?)?.cast<String>() ?? [];
      List<String> answers = (data["answers"] as List?)?.cast<String>() ?? [];

      int marksObtained = 0;
      if (selections.isEmpty) {
        marksObtained = 0;
      } else if (selections.length == answers.length &&
          selections.every((s) => answers.contains(s))) {
        marksObtained = 4;
      } else {
        marksObtained = -1;
      }

      List<Widget> correctAnswerWidgets = [
        Text(
          "Correct Answer(s):",
          style: GoogleFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
      for (var ans in answers) {
        correctAnswerWidgets.add(
          Text(
            ans,
            style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 16),
          ),
        );
      }

      List<Widget> selectionWidgets = [
        Text(
          "Your Selection(s):",
          style: GoogleFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
      if (selections.isEmpty) {
        selectionWidgets.add(
          Text(
            "None",
            style: GoogleFonts.poppins(
              color: Colors.orangeAccent,
              fontSize: 16,
            ),
          ),
        );
      } else {
        for (var sel in selections) {
          bool isCorrect = answers.contains(sel);
          selectionWidgets.add(
            Text(
              sel,
              style: GoogleFonts.poppins(
                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                fontSize: 16,
              ),
            ),
          );
        }
      }

      resultData.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          width: double.infinity,
          child: Card(
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Q${i + 1}: ${resultDataset["question"] as String? ?? ""}",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFE2E8F0),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Marks Obtained:",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "$marksObtained",
                        style: GoogleFonts.poppins(
                          color: marksObtained > 0
                              ? Colors.greenAccent
                              : (marksObtained < 0
                                    ? Colors.redAccent
                                    : Colors.orangeAccent),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: correctAnswerWidgets,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: selectionWidgets,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    resultData.add(const SizedBox(height: 50));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Results",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: resultData,
        ),
      ),
    );
  }
}

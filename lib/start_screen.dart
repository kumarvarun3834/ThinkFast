import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/quesations.dart';

class Main_Screen extends StatelessWidget {
  final Function(Widget) onPressed;

  Main_Screen({super.key, required this.onPressed});

  List<Widget> quizCards(BuildContext context) {
    return List.generate(dataset.length, (index) {
      final data = dataset[index];
      return Card(
        margin: const EdgeInsets.all(15),
        elevation: 3,
        color: const Color.fromARGB(255, 255, 225, 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextContainer(data["title"] as String, Colors.white, 24),
                    const SizedBox(height: 5),
                    const Text(
                      "Are you ready?",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  // Pass this quiz data to the next screen
                  onPressed(Quesations(
                    data["data"] as List<Map<String, Object>>,
                    onStateChange: onPressed,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  "START",
                  style: GoogleFonts.poppins(
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: quizCards(context),
      ),
    );
  }
}

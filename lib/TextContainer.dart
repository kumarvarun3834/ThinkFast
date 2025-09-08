import 'package:flutter/material.dart';

class TextContainer extends StatelessWidget {
  // Required parameters
  final String text;
  final Color colour;
  final double f;

  // Optional named parameters for additional styling
  final FontWeight? fontWeight; // Nullable FontWeight
  final TextAlign? textAlign;   // Nullable TextAlign

  // Constructor with required positional parameters and optional named parameters
  const TextContainer(
      this.text,
      this.colour,
      this.f, {
        super.key,
        this.fontWeight, // Initialize the optional fontWeight
        this.textAlign,  // Initialize the optional textAlign
      });

  @override
  Widget build(BuildContext context) { // Use BuildContext context for clarity
    return Text(
      text,
      textAlign: textAlign, // Apply the optional textAlign
      style: TextStyle(
        color: colour,
        fontSize: f,
        fontWeight: fontWeight, // Apply the optional fontWeight
        // letterSpacing: 3, // Keep your existing style if desired
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:quizarea/TextContainer.dart'; // Make sure this path is correct for your TextContainer

class MarksPanel extends StatelessWidget {
  final int totalCorrectAnswers; // You will provide this calculated value
  final int totalQuestions;     // You will provide this calculated value

  const MarksPanel({
    super.key,
    required this.totalCorrectAnswers,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    // This calculation for percentage will still be here, but it uses the values you pass in.
    final double percentage = totalQuestions > 0 ? (totalCorrectAnswers / totalQuestions) : 0.0;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          TextContainer("Quiz Completed!", Colors.white, 30, fontWeight: FontWeight.bold),
          const SizedBox(height: 30), // Increased spacing

          SizedBox(
            width: 180, // Size of the circular panel
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle (e.g., a subtle outline or a solid color)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueGrey[800]?.withOpacity(0.7), // Darker, slightly transparent background
                    border: Border.all(color: Colors.white10, width: 2), // Subtle border
                  ),
                ),
                // Circular Progress Indicator (its 'value' will reflect your percentage)
                SizedBox(
                  width: 160, // Slightly smaller than container to show background circle
                  height: 160,
                  child: CircularProgressIndicator(
                    value: percentage, // This will be your calculated percentage (e.g., 0.8 for 80%)
                    strokeWidth: 15, // Thickness of the progress bar
                    backgroundColor: Colors.blueGrey[600], // Color of the track
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent), // Color of the progress itself
                  ),
                ),
                // Score Text in the center
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextContainer(
                      "Score",
                      Colors.white70,
                      18,
                      fontWeight: FontWeight.bold,
                    ),
                    TextContainer(
                      "$totalCorrectAnswers / $totalQuestions", // Displays your calculated score
                      Colors.amberAccent, // Bright gold for the score
                      38, // Larger score font
                      fontWeight: FontWeight.w900, // Very bold
                    ),
                    TextContainer(
                      "${(percentage * 100).toInt()}%", // Displays your calculated percentage
                      Colors.white54,
                      16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // You can put dynamic feedback here based on your own calculations
          TextContainer(
            (percentage * 100).toInt()>75?"Keep up the great work!":
            (percentage * 100).toInt()<25?"Better Luck Next Time":
                "need improvement!"

            , // Placeholder message
            Colors.white70,
            18,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final String title;

  const MarksPanel({
    super.key,
    required this.totalCorrectAnswers,
    required this.totalQuestions,
    this.title = "Quiz Completed!",
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
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFFE2E8F0),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(color: const Color(0xFF334155), width: 2),
                  ),
                ),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Score",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "$totalCorrectAnswers/$totalQuestions",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFE2E8F0),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "${(percentage * 100).toInt()}%",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF3B82F6),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            (percentage * 100).toInt() > 75
                ? "Excellent Work!"
                : (percentage * 100).toInt() < 25
                    ? "Better Luck Next Time"
                    : "Good Effort!",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF94A3B8),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
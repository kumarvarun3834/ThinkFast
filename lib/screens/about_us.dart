import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  // Colors (Consistent with ThinkFast Theme)
  final Color _bgColor = global.bgColor;
  final Color _cardColor = global.cardColor;
  final Color _primaryAccent = global.primaryAccent;
  final Color _valueColor = global.valueColor;
  final Color _labelColor = global.labelColor;
  final Color _borderColor = global.borderColor;

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _valueColor,
        ),
      ),
    );
  }

  Widget _buildContentText(String content) {
    return Text(
      content,
      style: GoogleFonts.poppins(fontSize: 16, color: _labelColor, height: 1.5),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryAccent, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _valueColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(fontSize: 14, color: _labelColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "ABOUT US",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _valueColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset('assets/images/quiz-logo.png', height: 180),
                  const SizedBox(height: 16),
                  Text(
                    "ThinkFast",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _valueColor,
                    ),
                  ),
                  Text(
                    "Challenge Your Mind",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: _primaryAccent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionTitle("The Project"),
            _buildContentText(
              "ThinkFast is a high-performance quiz platform designed for modern learning. "
              "Whether you're a student looking to test your knowledge or a creator building "
              "engaging challenges, ThinkFast provides the tools you need in one sleek interface.",
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("Key Capabilities"),
            _buildFeatureItem(
              Icons.create_rounded,
              "Dynamic Quiz Creation",
              "Build complex quizzes with multiple-choice questions, custom timers, and descriptions.",
            ),
            _buildFeatureItem(
              Icons.visibility_rounded,
              "Instant Privacy Control",
              "Quickly toggle your quizzes between Public and Private status with a single tap.",
            ),
            _buildFeatureItem(
              Icons.history_edu_rounded,
              "My Attempts",
              "Track your personal growth with a detailed history of your scores and performance across all quizzes.",
            ),
            _buildFeatureItem(
              Icons.analytics_rounded,
              "Creator Analytics",
              "View detailed responses for your quizzes, sorted by attempts and user IDs for precise insights.",
            ),
            _buildFeatureItem(
              Icons.security_rounded,
              "Firestore Security",
              "Real-time data protection ensuring your private quizzes and personal results remain secure.",
            ),
            const SizedBox(height: 32),
            _buildSectionTitle("The Tech Stack"),
            _buildContentText(
              "Built using Flutter for a buttery-smooth UI and powered by Firebase Firestore "
              "for real-time data synchronization and scalable backend operations.",
            ),
            const SizedBox(height: 48),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                "© 2024 ThinkFast. Developed for Internship Task.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: _labelColor),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

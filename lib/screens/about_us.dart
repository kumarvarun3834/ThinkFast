import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/widgets/TextContainer.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildContentText(String content) {
    return Text(
      content,
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.white70,
        height: 1.5,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
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
      appBar: AppBar(
        title: const TextContainer("About Us", Colors.black, 20),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.bolt, size: 80, color: Colors.amber),
                    const SizedBox(height: 10),
                    Text(
                      "ThinkFast",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Challenge Your Mind",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildSectionTitle("The Project"),
              _buildContentText(
                "ThinkFast is a dynamic quiz platform developed as part of an Internship Task. "
                "It aims to provide an interactive and engaging experience for users to test their knowledge, "
                "create their own challenges, and track their growth over time.",
              ),
              const SizedBox(height: 20),
              _buildSectionTitle("Key Features"),
              _buildFeatureItem(
                Icons.create,
                "Quiz Creation",
                "Easily create, update, and manage your own custom quizzes with multiple-choice questions.",
              ),
              _buildFeatureItem(
                Icons.timer,
                "Timed Challenges",
                "Test your speed and accuracy with customizable time limits for each quiz session.",
              ),
              _buildFeatureItem(
                Icons.history,
                "Attempt Tracking",
                "Review your past performances and see how you've improved through a detailed attempt history.",
              ),
              _buildFeatureItem(
                Icons.security,
                "Secure & Private",
                "Advanced Firestore security rules ensure your data and private quizzes are safe.",
              ),
              _buildFeatureItem(
                Icons.analytics,
                "Creator Insights",
                "Quiz owners can see detailed responses and performance metrics for the quizzes they've created.",
              ),
              const SizedBox(height: 30),
              _buildSectionTitle("Our Goal"),
              _buildContentText(
                "To build a robust, scalable, and user-friendly application that demonstrates the power of Flutter "
                "and Firebase in creating modern mobile experiences.",
              ),
              const SizedBox(height: 40),
              const Divider(color: Colors.white24),
              Center(
                child: Text(
                  "© 2024 ThinkFast. All rights reserved.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

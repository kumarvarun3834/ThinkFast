import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/recommendation_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to see recommendations")),
      );
    }

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        title: Text(
          "RECOMMENDATIONS",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _recommendationService.streamRecommendations(_uid!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: global.primaryAccent),
                );
              }

              final recommendations = snapshot.data ?? [];

              if (recommendations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 64,
                        color: global.labelColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No recommendations yet.",
                        style: GoogleFonts.poppins(color: global.labelColor),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Complete more quizzes to help AI understand your learning gaps.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: global.labelColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final rec = recommendations[index];
                  return _buildRecommendationCard(rec);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final String title = rec['title'] ?? 'Untitled Quiz';
    final String reason = rec['reason'] ?? rec['why'] ?? 'Recommended for you';
    final String topic = rec['targetTopic'] ?? 'General';
    final int qCount = rec['totalQuestions'] ?? 0;
    final String date = rec['timestamp'] ?? 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: global.borderColor),
      ),
      child: Material(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/Quiz Details',
              arguments: rec['quizId'],
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: global.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: global.primaryAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        topic.toUpperCase(),
                        style: const TextStyle(
                          color: global.primaryAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      date.split(' at ').first, // Just the date part
                      style: const TextStyle(
                        color: global.labelColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: global.valueColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.quiz_outlined,
                      size: 14,
                      color: global.labelColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$qCount Questions",
                      style: const TextStyle(
                        color: global.labelColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Divider(color: global.borderColor, height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: global.valueColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/Quiz Details',
                        arguments: rec['quizId'],
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: global.primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "START RECOMMENDED QUIZ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

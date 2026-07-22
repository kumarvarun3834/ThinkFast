import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/utils/global.dart' as global;

class LeaderboardScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const LeaderboardScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Leaderboard",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboards')
            .doc(widget.quizId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState("No rankings generated yet.");
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final entries = List<Map<String, dynamic>>.from(
            data['entries'] ?? [],
          );
          final isPublic = data['isPublic'] ?? true;

          if (!isPublic && !global.isAdmin) {
            return _buildEmptyState("This leaderboard is currently private.");
          }

          if (entries.isEmpty) {
            return _buildEmptyState("No rankings generated yet.");
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  widget.quizTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: global.valueColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data['title'] ?? 'Official Rankings',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: global.primaryAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data['description'] != null &&
                    data['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data['description'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: global.labelColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                _buildLeaderboardList(entries),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "Last Updated: ${_formatTimestamp(data['updatedAt'])}",
                    style: const TextStyle(
                      color: global.hintColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "N/A";
    final date = (ts as Timestamp).toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> entries) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: global.borderColor),
      ),
      child: Material(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (context, index) =>
              const Divider(color: global.borderColor, height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final rank = entry['rank'] ?? (index + 1);
            final isTop3 = rank <= 3;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isTop3
                      ? (rank == 1
                                ? Colors.amber
                                : (rank == 2 ? Colors.grey : Colors.brown))
                            .withValues(alpha: 0.2)
                      : global.bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "#$rank",
                    style: TextStyle(
                      color: isTop3
                          ? (rank == 1
                                ? Colors.amber
                                : (rank == 2
                                      ? Colors.white70
                                      : Colors.brown[300]))
                          : global.labelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              title: Text(
                entry['name'] ?? 'Anonymous',
                style: GoogleFonts.poppins(
                  color: global.valueColor,
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: Text(
                "${entry['score']} pts",
                style: GoogleFonts.poppins(
                  color: global.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.leaderboard_outlined,
              size: 48,
              color: global.borderColor,
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: const TextStyle(color: global.labelColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

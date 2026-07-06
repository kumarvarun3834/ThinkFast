import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportedContentScreen extends StatefulWidget {
  const ReportedContentScreen({super.key});

  @override
  State<ReportedContentScreen> createState() => _ReportedContentScreenState();
}

class _ReportedContentScreenState extends State<ReportedContentScreen> {
  final AdminService _adminService = AdminService();
  final String _adminId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Reported Content",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getContentReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Text(
                "No reports found.",
                style: TextStyle(color: global.labelColor),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final String status = report['status'] ?? 'pending';
              
              return Card(
                color: global.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: status == 'pending' ? global.errorColor.withValues(alpha: 0.5) : global.borderColor,
                  ),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      _buildTypeBadge(report['targetType'] ?? 'quiz'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report['reason'] ?? 'No reason provided',
                          style: const TextStyle(
                            color: global.valueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (report['details'] != null && report['details'].toString().isNotEmpty)
                        Text(
                          report['details'],
                          style: const TextStyle(color: global.labelColor, fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        "Reported by: ${report['reporterId']}",
                        style: TextStyle(color: global.labelColor.withValues(alpha: 0.7), fontSize: 10),
                      ),
                      Text(
                        "Time: ${_formatTimestamp(report['timestamp'])}",
                        style: TextStyle(color: global.labelColor.withValues(alpha: 0.7), fontSize: 10),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (status == 'pending')
                        const Icon(Icons.error_outline, color: global.errorColor, size: 20)
                      else
                        const Icon(Icons.check_circle_outline, color: global.successColor, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'pending' ? global.errorColor : global.successColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showReportActions(report),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: global.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: global.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(color: global.primaryAccent, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "N/A";
    final date = (ts as Timestamp).toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _showReportActions(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: global.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report Details",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: global.valueColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow("Target Type", report['targetType']),
            _buildDetailRow("Reason", report['reason']),
            _buildDetailRow("Details", report['details'] ?? "None"),
            _buildDetailRow("Quiz ID", report['quizId']),
            if (report['questionId'] != null)
              _buildDetailRow("Question ID", report['questionId']),
            const Divider(color: global.borderColor, height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/Quiz Details',
                        arguments: report['quizId'],
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text("REVIEW QUIZ"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(report['id'], 'dismissed'),
                    icon: const Icon(Icons.close),
                    label: const Text("DISMISS REPORT"),
                    style: OutlinedButton.styleFrom(foregroundColor: global.labelColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(report['id'], 'resolved'),
                    icon: const Icon(Icons.done_all),
                    label: const Text("MARK RESOLVED"),
                    style: ElevatedButton.styleFrom(backgroundColor: global.successColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(color: global.labelColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: value ?? "N/A",
              style: const TextStyle(color: global.valueColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String reportId, String status) async {
    try {
      await _adminService.updateReportStatus(reportId, status, _adminId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Report $status")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}

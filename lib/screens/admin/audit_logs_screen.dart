import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/admin_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  DateTime? _lastRefresh;
  bool _canView = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  void _checkAccess() {
    final bool isMaster = global.adminLevel == 0;
    final bool hasViewPerm = global.adminPermissions.contains('view_audit_logs');
    
    _canView = isMaster || hasViewPerm;
    // Only Master Admin can clear logs for security integrity
    _canDelete = isMaster;
    
    if (_canView) {
      _refreshLogs(force: true);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshLogs({bool force = false}) async {
    if (!_canView) return;

    final bool canBypass =
        global.adminLevel == 0 ||
        global.adminPermissions.contains('view_audit_logs') ||
        global.featureFlags?['enable_refresh_limit_bypass'] == true;

    if (!force && !canBypass && _lastRefresh != null) {
      final int limit =
          global.featureFlags?['admin_refresh_rate_limit_seconds'] ?? 30;
      final difference = DateTime.now().difference(_lastRefresh!).inSeconds;
      if (difference < limit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please wait ${limit - difference}s before refreshing again.",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final logs = await _adminService.fetchAllAuditLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching logs: $e")));
      }
    }
  }

  Future<void> _clearLogs() async {
    if (!_canDelete) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: global.cardColor,
        title: const Text("Clear All Logs?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently delete all audit log data. This action cannot be undone.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: global.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CLEAR ALL"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _adminService.clearAuditLogs();
        await _refreshLogs(force: true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audit logs cleared")));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error clearing logs: $e")));
        }
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'admin':
        return Colors.orangeAccent;
      case 'quiz':
        return global.primaryAccent;
      case 'moderation':
        return global.errorColor;
      case 'user':
        return Colors.greenAccent;
      default:
        return global.labelColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("Audit Logs")),
        body: const Center(
          child: Text("Access Denied: Log viewing is disabled.", style: TextStyle(color: global.errorColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Audit Logs",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: global.errorColor),
              onPressed: _clearLogs,
              tooltip: "Clear All Logs",
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: global.valueColor),
            onPressed: () => _refreshLogs(),
            tooltip: "Refresh Logs",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            )
          : _logs.isEmpty
          ? const Center(
              child: Text(
                "No logs found.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final dynamic timestamp = log['timestamp'];
                String dateStr = 'N/A';
                if (timestamp != null) {
                  DateTime? dt;
                  if (timestamp is Timestamp) {
                    dt = timestamp.toDate();
                  } else if (timestamp is DateTime) {
                    dt = timestamp;
                  } else if (timestamp is String) {
                    dt = DateTime.tryParse(timestamp);
                  }

                  if (dt != null) {
                    // Manual formatting to avoid intl dependency
                    final day = dt.day.toString().padLeft(2, '0');
                    final months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    final month = months[dt.month - 1];
                    final hour = dt.hour.toString().padLeft(2, '0');
                    final minute = dt.minute.toString().padLeft(2, '0');
                    final second = dt.second.toString().padLeft(2, '0');
                    dateStr = "$day $month, $hour:$minute:$second";
                  }
                }

                return Card(
                  color: global.cardColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: global.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                  log['category'] ?? 'general',
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getCategoryColor(
                                    log['category'] ?? 'general',
                                  ),
                                ),
                              ),
                              child: Text(
                                (log['category'] ?? 'GENERAL')
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: _getCategoryColor(
                                    log['category'] ?? 'general',
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: global.labelColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (log['action'] ?? 'Unknown Action')
                              .toString()
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: global.valueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          log['details'] ?? 'No details provided',
                          style: const TextStyle(
                            color: global.labelColor,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(color: global.borderColor, height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: global.labelColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Actor: ${log['actorName'] ?? 'Unknown'} (${log['actorId']})",
                                style: const TextStyle(
                                  color: global.labelColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: global.labelColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Target: ${log['targetId']}",
                                style: const TextStyle(
                                  color: global.labelColor,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

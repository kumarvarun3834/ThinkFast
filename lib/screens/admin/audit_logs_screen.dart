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
  String _selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  void _checkAccess() {
    final bool isMaster = global.adminLevel == 0;
    final bool hasViewPerm = global.adminPermissions.contains(
      'view_audit_logs',
    );

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
        title: const Text(
          "Clear All Logs?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will permanently delete all audit log data. This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Audit logs cleared")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error clearing logs: $e")));
        }
      }
    }
  }

  Widget _buildSidePanel() {
    final categories = ["All", "Admin", "Quiz", "Moderation", "User"];

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: global.cardColor,
        border: Border(right: BorderSide(color: global.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "LOG CATEGORIES",
              style: GoogleFonts.poppins(
                color: global.primaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: global.primaryAccent.withValues(
                    alpha: 0.1,
                  ),
                  title: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? global.primaryAccent
                          : global.valueColor,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          const Divider(color: global.borderColor),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SUMMARY",
                  style: GoogleFonts.poppins(
                    color: global.labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatItem("Total Logs", _logs.length.toString()),
                if (_selectedCategory != "All") ...[
                  const SizedBox(height: 12),
                  _buildStatItem(
                    "$_selectedCategory Logs",
                    _logs
                        .where(
                          (l) =>
                              (l['category'] ?? 'general')
                                  .toString()
                                  .toLowerCase() ==
                              _selectedCategory.toLowerCase(),
                        )
                        .length
                        .toString(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: global.valueColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: global.labelColor, fontSize: 12),
        ),
      ],
    );
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
    final bool isLargeScreen = MediaQuery.of(context).size.width > 900;

    if (!_canView) {
      return Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Audit Logs"),
        ),
        body: const Center(
          child: Text(
            "Access Denied: Log viewing is disabled.",
            style: TextStyle(color: global.errorColor),
          ),
        ),
      );
    }

    var filteredLogs = _logs;
    if (_selectedCategory != "All") {
      filteredLogs = _logs
          .where(
            (log) =>
                (log['category'] ?? 'general').toString().toLowerCase() ==
                _selectedCategory.toLowerCase(),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isLargeScreen
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: global.valueColor),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Text(
          "Audit Logs",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: global.errorColor,
              ),
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
      drawer: isLargeScreen
          ? null
          : Drawer(
              backgroundColor: global.cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: global.bgColor),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Categories',
                        style: GoogleFonts.poppins(
                          color: global.valueColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: ["All", "Admin", "Quiz", "Moderation", "User"]
                          .map(
                            (cat) => ListTile(
                              selected: _selectedCategory == cat,
                              title: Text(
                                cat,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                setState(() => _selectedCategory = cat);
                                Navigator.pop(context);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 1200 : 800),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: global.primaryAccent),
                )
              : isLargeScreen
              ? Row(
                  children: [
                    _buildSidePanel(),
                    Expanded(
                      child: filteredLogs.isEmpty
                          ? const Center(
                              child: Text(
                                "No logs found for this category.",
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                return _buildLogCard(filteredLogs[index]);
                              },
                            ),
                    ),
                  ],
                )
              : filteredLogs.isEmpty
              ? const Center(
                  child: Text(
                    "No logs found.",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    return _buildLogCard(filteredLogs[index]);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
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
          'Dec',
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
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getCategoryColor(log['category'] ?? 'general'),
                    ),
                  ),
                  child: Text(
                    (log['category'] ?? 'GENERAL').toString().toUpperCase(),
                    style: TextStyle(
                      color: _getCategoryColor(log['category'] ?? 'general'),
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
              style: const TextStyle(color: global.labelColor, fontSize: 13),
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
  }
}

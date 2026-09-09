import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/ai_service.dart';
import 'package:thinkfast/services/api_client.dart';
import 'package:thinkfast/services/media_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Map<String, dynamic> _dashboardData = {};
  bool _isLoading = false;
  String _activeCategory = "Overview";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchCategoryData();
    // Auto-refresh monitoring data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _activeCategory != "Server Controls") {
        _fetchCategoryData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategoryData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      if (_activeCategory == "Overview" || _activeCategory == "System Health") {
        final responses = await Future.wait([
          ApiClient.instance.get(
            "${global.aiBackendUrl}/api/health",
            options: Options(headers: {'Content-Type': 'application/json'}),
          ),
          ApiClient.instance.get(
            "${global.aiBackendUrl}/api/admin/metrics",
            options: Options(headers: {'Content-Type': 'application/json'}),
          ),
        ]);

        if (mounted) {
          setState(() {
            _dashboardData['health'] = responses[0].data;
            _dashboardData['metrics'] = responses[1].data;
          });
        }
      } else if (_activeCategory == "Media Storage") {
        final status = await MediaService().getStorageStatus();
        if (mounted) {
          setState(() {
            _dashboardData['storage'] = status;
          });
        }
      }
    } catch (e) {
      debugPrint("Dashboard Refresh Error: $e");
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerAction(
    String path, {
    Map<String, dynamic>? body,
    bool destructive = false,
  }) async {
    if (destructive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: global.cardColor,
          title: const Text(
            "Confirm Action",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Are you sure you want to trigger $path? This action may be irreversible.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("PROCEED"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text("Executing $path...")));

    try {
      final response = await ApiClient.instance.post(
        "${global.aiBackendUrl}$path",
        data: body ?? {},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? "Success"
                  : "Error: ${response.statusCode}",
            ),
            backgroundColor: response.statusCode == 200
                ? Colors.green
                : Colors.redAccent,
          ),
        );
        _fetchCategoryData(silent: true);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Action Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled =
        global.featureFlags?['enable_admin_dashboard'] ?? true;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 800;

    if (!isEnabled) {
      return Scaffold(
        backgroundColor: global.bgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_person_rounded,
                color: global.errorColor,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                "Dashboard Disabled",
                style: GoogleFonts.poppins(
                  color: global.valueColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This feature has been disabled by the system administrator.",
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isSmallScreen ? "Admin Dash" : "Super Admin Dashboard",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: global.primaryAccent,
              size: 20,
            ),
            onPressed: () => _fetchCategoryData(),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(isSmallScreen),
          Expanded(child: _buildMainContent(isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isSmall) {
    final categories = [
      {"name": "Overview", "icon": Icons.dashboard_rounded},
      {"name": "Media Storage", "icon": Icons.cloud_done_rounded},
      {"name": "System Health", "icon": Icons.health_and_safety_rounded},
      {"name": "Active Monitoring", "icon": Icons.monitor_heart_rounded},
      {"name": "API Generation Tester", "icon": Icons.auto_awesome_rounded},
      {"name": "Server Controls", "icon": Icons.settings_remote_rounded},
    ];

    if (isSmall) {
      return NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: categories.indexWhere(
          (e) => e['name'] == _activeCategory,
        ),
        onDestinationSelected: (int index) {
          setState(() => _activeCategory = categories[index]['name'] as String);
          _fetchCategoryData();
        },
        labelType: NavigationRailLabelType.none,
        destinations: categories.map((cat) {
          return NavigationRailDestination(
            icon: Icon(cat['icon'] as IconData, color: global.labelColor),
            selectedIcon: Icon(
              cat['icon'] as IconData,
              color: global.primaryAccent,
            ),
            label: Text(cat['name'] as String),
          );
        }).toList(),
      );
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: global.borderColor)),
      ),
      child: ListView(
        children: categories.map((cat) {
          final String name = cat['name'] as String;
          final bool isActive = _activeCategory == name;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Material(
              color: isActive
                  ? global.primaryAccent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  cat['icon'] as IconData,
                  color: isActive ? global.primaryAccent : global.labelColor,
                  size: 20,
                ),
                title: Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: isActive ? global.primaryAccent : global.labelColor,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  setState(() => _activeCategory = name);
                  _fetchCategoryData();
                },
                selected: isActive,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainContent(bool isSmall) {
    Widget content;
    switch (_activeCategory) {
      case "Overview":
        content = _buildOverview(isSmall);
        break;
      case "Media Storage":
        content = _buildMediaStorage();
        break;
      case "System Health":
        content = _buildSystemHealth();
        break;
      case "Active Monitoring":
        content = _buildMonitoring();
        break;
      case "API Generation Tester":
        content = _buildApiTester();
        break;
      case "Server Controls":
        content = _buildControls();
        break;
      default:
        content = const Center(child: Text("Select a category"));
    }

    if (isSmall) return content;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: content,
      ),
    );
  }

  bool _isQueueProcessing = false;
  Map<String, dynamic>? _queueResult;

  Widget _buildApiTester() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader("Quiz Generation Queue"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: global.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Manual Queue Worker",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: global.valueColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Trigger the background worker to process pending quiz requests immediately. This bypasses the hourly schedule.",
                style: GoogleFonts.poppins(
                  color: global.labelColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              if (_queueResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: global.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: global.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: global.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Success: ${_queueResult!['processedCount'] ?? 0} requests cleared. TraceID: ${_queueResult!['traceId'] ?? 'N/A'}",
                          style: GoogleFonts.poppins(
                            color: global.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isQueueProcessing
                      ? null
                      : () async {
                          setState(() {
                            _isQueueProcessing = true;
                            _queueResult = null;
                          });
                          try {
                            final result = await AiService().processQuizQueue();
                            if (mounted) {
                              setState(() {
                                _queueResult = result;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Queue Error: $e"),
                                  backgroundColor: global.errorColor,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isQueueProcessing = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: global.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isQueueProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(
                    _isQueueProcessing ? "Worker Active..." : "PROCESS QUEUE",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionHeader("Core Execution Traces"),
        const SizedBox(height: 16),
        _buildTraceLogs(),
      ],
    );
  }

  Widget _buildTraceLogs() {
    // This would ideally pull from a stream of audit logs or a dedicated /api/admin/traces endpoint
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "RECENT TRACES",
                style: TextStyle(
                  color: global.labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _triggerAction("/api/admin/clear-traces"),
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  size: 14,
                  color: global.errorColor,
                ),
                label: const Text(
                  "CLEAR LOGS",
                  style: TextStyle(fontSize: 10, color: global.errorColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Fetching real-time execution logs...",
            style: TextStyle(
              color: global.hintColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaStorage() {
    final storage = _dashboardData['storage'] as Map? ?? {};
    final double usagePercent = (storage['usage_percent'] ?? 0.0).toDouble();
    final bool isHealthy = storage['health'] == 'healthy';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader("Media Storage Health"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: global.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHealthy
                  ? global.successColor.withValues(alpha: 0.3)
                  : global.errorColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storage['active_repo'] ?? "No Active Repo",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: global.valueColor,
                        ),
                      ),
                      Text(
                        "Current Sequential Storage",
                        style: TextStyle(
                          color: global.labelColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isHealthy ? Colors.green : Colors.red).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isHealthy ? "HEALTHY" : "CRITICAL",
                      style: TextStyle(
                        color: isHealthy
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Capacity Usage",
                    style: TextStyle(
                      color: global.valueColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${storage['size_mb'] ?? 0} MB / 5,000 MB",
                    style: TextStyle(color: global.labelColor, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercent / 100,
                  minHeight: 12,
                  backgroundColor: global.bgColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    usagePercent > 90
                        ? global.errorColor
                        : usagePercent > 70
                        ? global.warningColor
                        : global.successColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Auto-rotation triggers at 90% (4.5 GB). Current usage is ${usagePercent.toStringAsFixed(2)}%.",
                style: TextStyle(color: global.labelColor, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("Maintenance Controls"),
        const SizedBox(height: 16),
        _buildActionCard(
          "Forced Rotation",
          "Manually trigger the sequential repository rotation (vN -> vN+1). Use only for emergency migration.",
          Icons.rotate_right_rounded,
          () => _triggerAction(
            "/api/v1/media/repo/provision",
            body: {"forceRotate": true},
            destructive: true,
          ),
          isDestructive: true,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          "Provision Check",
          "Verify and initialize the active storage repository on GitHub if missing.",
          Icons.cloud_sync_rounded,
          () => _triggerAction(
            "/api/v1/media/repo/provision",
            body: {"forceRotate": false},
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("Repository Details"),
        const SizedBox(height: 16),
        _buildDetailCard("Full Storage JSON", storage),
      ],
    );
  }

  Widget _buildOverview(bool isSmall) {
    final metrics = _dashboardData['metrics'] as Map? ?? {};
    final health = _dashboardData['health'] as Map? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "System Summary",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: global.valueColor,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isSmall ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isSmall ? 1.5 : 2,
          children: [
            _buildInfoTile(
              "Status",
              health['status']?.toString() ?? "...",
              Icons.dns_rounded,
              color: health['status'] == "UP"
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
            _buildInfoTile(
              "Uptime",
              metrics['uptime']?.toString() ?? "0s",
              Icons.timer_rounded,
            ),
            _buildInfoTile(
              "Memory",
              metrics['memory']?.toString() ?? "0 MB",
              Icons.memory_rounded,
            ),
            _buildInfoTile("DB Mode", "Production", Icons.storage_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemHealth() {
    final health = _dashboardData['health'] ?? {};
    final metrics = _dashboardData['metrics'] ?? {};

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader("Service Integrity"),
        const SizedBox(height: 16),
        _buildDetailCard("Health Status", health),
        const SizedBox(height: 24),
        _buildSectionHeader("Server Metrics"),
        const SizedBox(height: 16),
        _buildDetailCard("System Load", metrics),
      ],
    );
  }

  Widget _buildMonitoring() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_graph_rounded, color: global.labelColor, size: 48),
            SizedBox(height: 16),
            Text(
              "Real-time Monitoring Active",
              style: TextStyle(
                color: global.valueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Active sessions and notifications are monitored directly via Firestore SDK on the main screens.",
              textAlign: TextAlign.center,
              style: TextStyle(color: global.labelColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader("Server Management"),
        const SizedBox(height: 16),
        _buildActionCard(
          "Database Reset",
          "Wipes restricted collections and resets the system to its initial state.",
          Icons.refresh_rounded,
          () => _triggerAction(
            "/api/admin/tasks",
            body: {"task": "reset_db"},
            destructive: true,
          ),
          isDestructive: true,
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          "Flush AI Queue",
          "Immediately processes all pending asynchronous generation requests.",
          Icons.bolt_rounded,
          () =>
              _triggerAction("/api/admin/tasks", body: {"task": "flush_queue"}),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? global.labelColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: global.labelColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: value == "Error" ? Colors.redAccent : global.valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: global.primaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: global.primaryAccent,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(String title, dynamic data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: global.labelColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                const JsonEncoder.withIndent('  ').convert(data),
                style: GoogleFonts.firaCode(
                  color: Colors.greenAccent,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String desc,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: global.borderColor),
      ),
      child: Material(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(
            icon,
            color: isDestructive ? Colors.redAccent : global.primaryAccent,
            size: 20,
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: global.valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            desc,
            style: const TextStyle(color: global.labelColor, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? Colors.redAccent
                  : global.btnColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(60, 32),
            ),
            onPressed: onTap,
            child: Text(
              isDestructive ? "DANGER" : "EXEC",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinkfast/services/settings_service.dart';
import 'package:thinkfast/utils/global.dart' as global;

// import 'user_details_screen.dart';
import 'add_app_admin_screen.dart';
import 'all_users_screen.dart';
import 'audit_logs_screen.dart';
import 'manage_admins_screen.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final SettingsService _settingsService = SettingsService();
  List<String> _permissions = [];
  bool _isMaster = false;
  late Stream<Map<String, dynamic>?> _featureFlagsStream;

  // Grouped Feature Flags
  final Map<String, List<String>> _flagGroups = {
    "System Control": [
      "maintenance_mode",
      "log",
      "log_updates",
      "log_deletes",
      "enable_analytics",
    ],
    "User & Moderation": [
      "enable_login",
      "enable_register",
      "enable_profile_edit",
      "enable_user_banning",
    ],
    "Quiz Operations": [
      "enable_create_quiz",
      "enable_edit_quiz",
      "enable_delete_quiz",
      "enable_take_quiz",
      "enable_import",
      "enable_export",
      "random_quiz_generator",
      "management_features",
      "enable_realtime_colab",
    ],
    "AI & Performance": [
      "enable_ai",
      "enable_ai_quota_bypass",
      "enable_quiz_creation_rate_limit",
      "enable_form_save_rate_limit",
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchAdminStatus();
    _featureFlagsStream = _settingsService.streamFeatureFlags(
      isAdmin: global.isAdmin,
    );
  }

  void _refreshPanel() {
    setState(() {
      _featureFlagsStream = _settingsService.streamFeatureFlags(
        isAdmin: global.isAdmin,
      );
    });
  }

  Future<void> _fetchAdminStatus() async {
    if (mounted) {
      setState(() {
        _permissions = global.adminPermissions;
        _isMaster = global.adminLevel == 0;
      });
    }
  }

  bool _canManageFlag(String key) {
    if (_isMaster) return true;

    // Mapping key to the required permission based on SettingsService documentation
    final Map<String, String> keyPermissionMap = {
      // Manage App Settings (public doc)
      'enable_ai': 'manage_app_settings',
      'enable_import': 'manage_app_settings',
      'enable_login': 'manage_app_settings',
      'enable_register': 'manage_app_settings',
      'enable_create_quiz': 'manage_app_settings',
      'enable_edit_quiz': 'manage_app_settings',
      'enable_delete_quiz': 'manage_app_settings',
      'enable_take_quiz': 'manage_app_settings',
      'enable_profile_edit': 'manage_app_settings',
      'enable_analytics': 'manage_app_settings',
      'enable_export': 'manage_app_settings',
      'maintenance_mode': 'manage_app_settings',
      'random_quiz_generator': 'manage_app_settings',

      // Manage Admins
      'admin_refresh_rate_limit_seconds': 'manage_admins',

      // Moderate Users
      'enable_user_banning': 'moderate_users',

      // Manage All Quizzes
      'enable_quiz_creation_rate_limit': 'manage_all_quizzes',
      'quiz_creation_rate_limit_minutes': 'manage_all_quizzes',
      'enable_form_save_rate_limit': 'manage_all_quizzes',
      'form_save_rate_limit_seconds': 'manage_all_quizzes',
      'management_features': 'manage_all_quizzes',

      // Bypass AI Quotas
      'enable_ai_quota_bypass': 'bypass_ai_quotas',
      'ai_daily_generation_limit': 'bypass_ai_quotas',

      // View Audit Logs
      'log': 'view_audit_logs',
      'log_updates': 'view_audit_logs',
      'log_deletes': 'view_audit_logs',

      // Manage Collaborators
      'enable_realtime_colab': 'manage_collaborators',
    };

    final requiredPerm = keyPermissionMap[key];
    if (requiredPerm == null) return _permissions.contains('manage_app_settings');
    return _permissions.contains(requiredPerm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: global.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Admin Panel",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            if (_isMaster)
              const Text(
                "MASTER CONTROL ENABLED",
                style: TextStyle(
                  color: global.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: global.valueColor),
            onPressed: _refreshPanel,
            tooltip: "Reload Settings",
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _featureFlagsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: global.primaryAccent),
            );
          }

          final flags = snapshot.data ?? {};

          // Collect all flags that are already grouped
          final groupedKeys = _flagGroups.values.expand((e) => e).toSet();
          groupedKeys.add('quiz_creation_rate_limit_minutes');
          groupedKeys.add('form_save_rate_limit_seconds');
          groupedKeys.add('ai_daily_generation_limit');
          groupedKeys.add('admin_refresh_rate_limit_seconds');

          // Find any flags in Firestore that are NOT in our groups
          final otherKeys = flags.keys
              .where((k) => !groupedKeys.contains(k) && k != 'updatedAt')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Platform Management"),
              const SizedBox(height: 12),
              _buildManagementTile(
                icon: Icons.people_alt_outlined,
                title: "User Management",
                subtitle: "View users, ban accounts, delete data",
                enabled: _isMaster || _permissions.contains('moderate_users'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllUsersScreen(),
                  ),
                ),
              ),
              _buildManagementTile(
                icon: Icons.admin_panel_settings_outlined,
                title: "Admin Management",
                subtitle: "Manage platform-wide administrators",
                enabled: _isMaster || _permissions.contains('manage_admins'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageAdminsScreen(),
                  ),
                ),
              ),
              _buildManagementTile(
                icon: Icons.person_add_alt_1_outlined,
                title: "Promote New Admin",
                subtitle: "Add and configure new app administrators",
                enabled: _isMaster || _permissions.contains('manage_admins'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddAppAdminScreen(),
                  ),
                ),
              ),
              _buildManagementTile(
                icon: Icons.history_edu_outlined,
                title: "View Audit Logs",
                subtitle: "Track system activity and admin actions",
                enabled: _isMaster || _permissions.contains('view_audit_logs'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuditLogsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ..._flagGroups.entries.map((group) {
                final groupFlags = group.value
                    .where((k) => flags.containsKey(k))
                    .toList();
                if (groupFlags.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(group.key),
                    const SizedBox(height: 12),
                    ...groupFlags.map((key) {
                      final bool value = flags[key] == true;
                      return _buildFlagToggle(key, value);
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              }),

              if (otherKeys.isNotEmpty) ...[
                _buildSectionHeader("Other Settings"),
                const SizedBox(height: 12),
                ...otherKeys.map((key) {
                  final value = flags[key];
                  if (value is bool) {
                    return _buildFlagToggle(key, value);
                  } else {
                    return _buildGenericField(key, value, flags);
                  }
                }),
                const SizedBox(height: 24),
              ],

              _buildSectionHeader("Rate Limits"),
              const SizedBox(height: 12),
              _buildRateLimitField(flags),
              const SizedBox(height: 24),

              _buildSectionHeader("Database Maintenance"),
              const SizedBox(height: 12),
              _buildManagementTile(
                icon: Icons.cleaning_services_outlined,
                title: "Cleanup Orphaned Tags",
                subtitle: "Remove tags with no associated quizzes",
                enabled:
                    _isMaster || _permissions.contains('manage_app_settings'),
                onTap: () async {
                  final String? adminId =
                      FirebaseAuth.instance.currentUser?.uid;
                  if (adminId == null) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: global.cardColor,
                      title: const Text(
                        "Cleanup Tags?",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        "This will permanently delete all tags that are not linked to any active quizzes.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("CANCEL"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("CLEANUP"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      final count = await global.adminDb.removeEmptyTags(adminId);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              "Successfully removed $count empty tag(s).",
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text("Cleanup Error: $e"),
                            backgroundColor: global.errorColor,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? global.borderColor
              : global.borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        onTap: enabled ? onTap : null,
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled
              ? global.primaryAccent
              : global.primaryAccent.withValues(alpha: 0.4),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: enabled
                ? global.valueColor
                : global.valueColor.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          enabled ? subtitle : "Insufficient Permission",
          style: TextStyle(
            color: enabled
                ? global.labelColor
                : global.errorColor.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: enabled
              ? global.labelColor
              : global.labelColor.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildGenericField(
    String key,
    dynamic value,
    Map<String, dynamic> flags,
  ) {
    final bool canManage = _canManageFlag(key);
    final String displayTitle = key.replaceAll('_', ' ').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canManage
              ? global.borderColor
              : global.borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: TextStyle(
                color: canManage
                    ? global.valueColor
                    : global.valueColor.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              enabled: canManage,
              controller: TextEditingController(text: value.toString()),
              style: TextStyle(
                color: canManage
                    ? global.valueColor
                    : global.valueColor.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (newVal) async {
                dynamic typedVal = newVal;
                if (value is int) typedVal = int.tryParse(newVal);
                if (value is double) typedVal = double.tryParse(newVal);

                if (typedVal != null) {
                  await _settingsService.updateFeatureFlag(key, typedVal);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        color: global.primaryAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFlagToggle(String key, bool value) {
    // Convert snake_case to Title Case for display
    String displayTitle = key
        .replaceFirst('enable_', '')
        .replaceFirst('log_', 'Log ')
        .split('_')
        .map((word) {
          if (word.isEmpty) return "";
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');

    if (key == 'log') displayTitle = "App Action Logging";
    if (key == 'log_updates') displayTitle = "Audit Log Viewing";
    if (key == 'log_deletes') displayTitle = "Audit Log Deletion";

    final bool canManage = _canManageFlag(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canManage
              ? global.borderColor
              : global.borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            displayTitle,
            style: TextStyle(
              color: canManage
                  ? global.valueColor
                  : global.valueColor.withValues(alpha: 0.4),
              fontSize: 16,
            ),
          ),
          subtitle: !canManage
              ? const Text(
                  "Insufficient Permission",
                  style: TextStyle(color: global.errorColor, fontSize: 12),
                )
              : null,
          value: value,
          activeTrackColor: global.primaryAccent.withValues(alpha: 0.5),
          activeThumbColor: global.primaryAccent,
          onChanged: canManage
              ? (newValue) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _settingsService.updateFeatureFlag(key, newValue);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text("Error updating $key: $e")),
                      );
                    }
                  }
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildRateLimitField(Map<String, dynamic> flags) {
    return Column(
      children: [
        _buildNumericField(
          flags: flags,
          key: 'quiz_creation_rate_limit_minutes',
          label: "Creation Rate Limit (Minutes)",
          defaultValue: 5,
        ),
        const SizedBox(height: 12),
        _buildNumericField(
          flags: flags,
          key: 'form_save_rate_limit_seconds',
          label: "Form Save Rate Limit (Seconds)",
          defaultValue: 30,
        ),
        const SizedBox(height: 12),
        _buildNumericField(
          flags: flags,
          key: 'ai_daily_generation_limit',
          label: "AI Daily Generation Limit",
          defaultValue: 10,
        ),
        const SizedBox(height: 12),
        _buildNumericField(
          flags: flags,
          key: 'admin_refresh_rate_limit_seconds',
          label: "Admin Log Refresh Limit (Seconds)",
          defaultValue: 30,
        ),
      ],
    );
  }

  Widget _buildNumericField({
    required Map<String, dynamic> flags,
    required String key,
    required String label,
    required int defaultValue,
  }) {
    final value = flags[key];
    final int currentVal = (value is num) ? value.toInt() : defaultValue;
    final bool canManage = _canManageFlag(key);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: global.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canManage
              ? global.borderColor
              : global.borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: canManage
                    ? global.valueColor
                    : global.valueColor.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              enabled: canManage,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: canManage
                    ? global.valueColor
                    : global.valueColor.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: global.borderColor),
                ),
              ),
              controller: TextEditingController(text: currentVal.toString()),
              onSubmitted: (val) async {
                final messenger = ScaffoldMessenger.of(context);
                final newValue = int.tryParse(val);
                if (newValue != null) {
                  try {
                    await _settingsService.updateFeatureFlag(key, newValue);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text("Error updating $key: $e")),
                      );
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
